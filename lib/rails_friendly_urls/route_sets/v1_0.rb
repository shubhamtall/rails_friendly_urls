
module ActionDispatch
  module Routing
    class RouteSet
      def recognize_path(path, environment = {})
        method = (environment[:method] || "GET").to_s.upcase
        path = Journey::Router::Utils.normalize_path(path) unless path =~ %r{://}
        extras = environment[:extras] || {}

        begin
          env = Rack::MockRequest.env_for(path, {:method => method})
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = @request_class.new(env)
        @router.recognize(req) do |route, _matches, params|
          params.merge!(extras)
          params.merge!(req.parameters.symbolize_keys)
          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY)
              params[key] = URI.parser.unescape(value)
            end
          end
          old_params = env[::ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
          env[::ActionDispatch::Routing::RouteSet::PARAMETERS_KEY] = (old_params || {}).merge(params)
          dispatcher = route.app
          while dispatcher.is_a?(Mapper::Constraints) && dispatcher.matches?(env) do
            dispatcher = dispatcher.app
          end

          if dispatcher.is_a?(Dispatcher)
            if dispatcher.controller(params, false)
              dispatcher.prepare_params!(params)
              return params
            else
              raise ActionController::RoutingError, "A route matches #{path.inspect}, but references missing controller: #{params[:controller].camelize}Controller"
            end
          elsif dispatcher.is_a?(PathRedirect)
            return { :status => dispatcher.status, :path => dispatcher.block }
          end
        end

        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end
    end
  end
end
