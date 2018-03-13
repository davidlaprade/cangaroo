module Cangaroo
  class PerformFlow
    include Interactor::Organizer

    organize ValidateJsonSchema,
             CountJsonObject,
             PerformJobs,
             PersistParameters
  end
end
