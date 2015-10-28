module Cangaroo
  class ValidateJsonSchema
    prepend SimpleCommand

    SCHEMA = {
      "type": "object",
      "maxProperties": 1,
      "additionalProperties": false,
      "patternProperties": {
        "^[a-z]*$": {
          "type": "object",
          "required": ["id"],
          "properties": {
            "id": {
              "type": "string",
            }
          }
        }
      }
    }.freeze

    def initialize(json_body)
      @json_body = json_body
    end

    def call
      json_errors = JSON::Validator.fully_validate(SCHEMA, @json_body)
      unless json_errors.empty?
        json_errors.each { |err| errors.add(:schema_error, err) }
        return false
      end
      true
    end
  end
end