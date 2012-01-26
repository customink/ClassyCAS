require 'rubygems'
require 'bundler'
Bundler.require
# Bundler.require doesn't seem to be pulling this in when used as gem...
require 'sinatra'
require 'redis'
require 'nokogiri'
require 'rack'
require 'rack-flash' 
require 'warden'

# Attempt to load Airbrake
begin
  require 'airbrake'
rescue LoadError
end

if RUBY_VERSION < "1.9"
  require 'backports'
  require 'system_timer'
end

require 'addressable/uri'

require_relative 'login_ticket'
require_relative 'proxy_ticket'
require_relative 'service_ticket'
require_relative 'ticket_granting_ticket'
require_relative 'strategies'

module ClassyCAS
  class Server < Sinatra::Base

    if defined?(Airbrake)
      enable :raise_errors
      use Airbrake::Rack
    end

    set :redis,               Proc.new { Redis.new }
    set :client_sites,        [ 'http://localhost:3001', 'http://localhost:3002' ]
    set :warden_strategies,   [ :simple ]
    set :warden_failure_app,  Proc.new { self }

    set :root,                File.dirname(__FILE__)
    set :public_folder,       Proc.new { File.join(root, "/../public") }

    # Since Sinatra's #set method works at the Class-level, it is not easy to configure
    # ClassyCAS when sub-classing it. This DSL method provides a clean way to do just that
    #
    #     class MyServer < ClassyCAS::Server
    #       classy_cas do
    #         set :warden_failure_app, MyFailureApp
    #       end
    #     end
    #
    def self.classy_cas( &block )
      Server.instance_eval( &block )
    end

    use Rack::Session::Cookie
    use Rack::Flash, :accessorize => [:notice, :error]
    use Warden::Manager do |manager|
      manager.failure_app = settings.warden_failure_app
      manager.default_scope = :cas

      manager.scope_defaults(:cas,
        :strategies => settings.warden_strategies,
        :action     => "login"
      )
    end

    configure :development do
      enable :dump_errors
      enable :logging
    end

    get "/" do
      redirect "/login"
    end

    get "/login" do
      @service_url = Addressable::URI.parse(params[:service])
      @renew = [true, "true", "1", 1].include?(params[:renew])
      @gateway = [true, "true", "1", 1].include?(params[:gateway])

      if @renew
        @login_ticket = LoginTicket.create!(settings.redis)
        render_login
      elsif @gateway
        if @service_url
          if sso_session
            st = ServiceTicket.new( @service_url.omit(:query).to_s, sso_session.username)
            st.save!(settings.redis)
            redirect_url = @service_url.clone
            if @service_url.query_values.nil?
              redirect_url.query_values = @service_url.query_values = {:ticket => st.ticket}
            else
              redirect_url.query_values = @service_url.query_values.merge(:ticket => st.ticket)
            end
            redirect redirect_url.to_s, 303
          else
            redirect @service_url.to_s, 303
          end
        else
          @login_ticket = LoginTicket.create!(settings.redis)
          render_login
        end
      else
        if sso_session
          if @service_url
            st = ServiceTicket.new(@service_url.omit(:query).to_s, sso_session.username)
            st.save!(settings.redis)
            redirect_url = @service_url.clone
            if @service_url.query_values.nil?
              redirect_url.query_values = @service_url.query_values = {:ticket => st.ticket}
            else
              redirect_url.query_values = @service_url.query_values.merge(:ticket => st.ticket)
            end
            redirect redirect_url.to_s, 303
          else
            render_logged_in
          end
        else
          @login_ticket = LoginTicket.create!(settings.redis)
          render_login
        end
      end
    end

    post '/unauthenticated' do
      @service_url = Addressable::URI.parse(params[:service])
      flash[:error] = env['warden.options'][:message] || "Invalid username or password"
      @login_ticket = LoginTicket.create!(settings.redis) unless login_ticket

      render_login
    end

    post "/login" do
      username = params[:username]
      password = params[:password]

      service_url = Addressable::URI.parse(params[:service])

      warn = [true, "true", "1", 1].include? params[:warn]
      # Spec is undefined about what to do without these params, so redirecting to credential requestor
      redirect "/login", 303 unless username && password && login_ticket
      # Failures will throw back to the settings.warden_failure_app value which is registered with Warnden to handle login failure.
      # By default settings.warden_failure_app is self (but can be overridden to any Rack App)
      warden.authenticate!(:scope => :cas, :action => 'unauthenticated' )

      tgt = TicketGrantingTicket.create!(username, settings.redis)
      cookie = tgt.to_cookie(request.host)
      response.set_cookie(*cookie)

      if service_url && !warn
        st = ServiceTicket.new( service_url.omit(:query), username)
        st.save!(settings.redis)

        redirect_url = service_url.clone
        if service_url.query_values.nil?
          redirect_url.query_values = service_url.query_values = {:ticket => st.ticket}
        else
          redirect_url.query_values = service_url.query_values.merge(:ticket => st.ticket)
        end
        redirect redirect_url.to_s, 303
      else
        render_logged_in
      end
    end
    
    get %r{(proxy|service)Validate} do
      service_url = params[:service]
      ticket = params[:ticket]
      # proxy_gateway = params[:pgtUrl]
      # renew = params[:renew]
    
      xml = if service_url && ticket
      if service_ticket
        if service_ticket.valid_for_service?(service_url)
          render_validation_success service_ticket.username
        else
          render_validation_error(:invalid_service)
        end
      else
        render_validation_error(:invalid_ticket, "ticket #{ticket} not recognized")
      end
      else
        render_validation_error(:invalid_request)
      end
    
      content_type :xml
      xml
    end
    
    
    get '/logout' do
      @url = params[:url]

      logout_user if sso_session

      @login_ticket = LoginTicket.create!(settings.redis)
      @logout = true
      render_logout
    end

    def render_login
      erb :login
    end

    def render_logged_in
      erb :logged_in
    end

    def render_logout
      render_login
    end

    # Override to add user info back to client applications
    def append_user_info(username, xml); end

    def logout_user
      sso_session.destroy!(settings.redis)
      response.delete_cookie(*sso_session.to_cookie(request.host))
      warden.logout(:cas)
      flash.now[:notice] = logged_out_notice
    end

    def logged_out_notice
      "Logout Successful.".tap do |notice|
        if @url
          notice << "  The application you just logged out of has provided a link it would like you to follow."
          notice << "Please <a href=\"#{@url}\">click here</a> to access <a href=\"#{@url}\">#{@url}</a>"      
        end
      end
    end

    private
      def warden
        request.env["warden"]
      end
    
      def sso_session
        @sso_session ||= TicketGrantingTicket.validate(request.cookies["tgt"], settings.redis)
      end
      
      def ticket_granting_ticket
        @ticket_granting_ticket ||= sso_session
      end
    
      def login_ticket
        @login_ticket ||= LoginTicket.validate!(params[:lt], settings.redis)
      end
    
      def service_ticket
        @service_ticket ||= ServiceTicket.find!(params[:ticket], settings.redis)
      end
    
      def render_validation_error(code, message = nil)
        xml = Nokogiri::XML::Builder.new do |xml|
          xml.serviceResponse("xmlns:cas" => "http://www.yale.edu/tp/cas") {
            xml.parent.namespace = xml.parent.namespace_definitions.first
            xml['cas'].authenticationFailure(message, :code => code.to_s.upcase){
            }
          }
        end
        xml.to_xml
      end
    
      def render_validation_success(username)
        xml = Nokogiri::XML::Builder.new do |xml|
          xml.serviceResponse("xmlns:cas" => "http://www.yale.edu/tp/cas") {
            xml.parent.namespace = xml.parent.namespace_definitions.first
            xml['cas'].authenticationSuccess {
              xml['cas'].user username
              append_user_info(username, xml)
            }
          }
        end
        xml.to_xml
      end
  end
end