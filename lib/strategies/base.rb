require 'warden'

module ClassyCAS
  module Strategies
    class Base < Warden::Strategies::Base
      
      def valid?
        params["username"] && params["password"]
      end
      
      def fail!(message = "Failed to Login")
        super
        redirect_to_login_with_service_url
      end

      # Casuses the strategy to fail, but not halt.  The strategies will cascade after this failure and warden will check the next strategy.  The last strategy to fail will have it's message displayed.
      # :api: public
      def fail(message = "Failed to Login")
        super
        redirect_to_login_with_service_url
      end
      
      def redirect_to_login_with_service_url
        redirect!("/login", {:service => params["service"]}, :message => "Login was not successful")
      end
    end
  end
end