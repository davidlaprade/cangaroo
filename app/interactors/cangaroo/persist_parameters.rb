module Cangaroo
  class PersistParameters
    include Interactor

    def call
      return if request_params.empty? || new_params.empty?
      unless connection.update(parameters: new_params)
        fail_context!
      end
    end

    private

    def new_params
      persisted_params
        .with_indifferent_access
        .merge(request_params)
        .slice(*persisted_params.keys)
    end

    def connection
      context.flow.send(:destination_connection)
    end

    def persisted_params
      connection.parameters
    end

    def request_params
      context.parameters.to_h.select{|k,v| v.present?}
    end

    def fail_context!
      context.fail!(
        message: "could not update #{context.flow.class.name} parameters: #{connection.errors.full_messages.to_sentence}",
        error_code: 500
      )
    end
  end
end
