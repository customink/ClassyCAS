require 'warden'

module ClassyCAS
  module Strategies
    class Base < Warden::Strategies::Base

      def valid?
        params["username"] && params["password"]
      end

    end
  end
end