module AsyncCounterCache
  class CounterUpdateWorker < ActiveJob::Base
    def perform(record, counter_name, reflection_name)
      new_count = record.public_send(reflection_name).count
      return if record[counter_name] == new_count
      record.update_columns counter_name => new_count, :updated_at => Time.current
    end
  end

  module RailsIntegration
    extend ActiveSupport::Concern

    module AssociationBuilderExtension
      def self.build(model, reflection)
        counter_name = reflection.options[:async_counter_cache]
        return unless counter_name.present?

        model.after_commit do
          CounterUpdateWorker.perform_later(self, counter_name.to_s, reflection.name.to_s)
        end

        if reflection.has_inverse?
          reflection.klass.after_commit do
            record = self.public_send(reflection.inverse_of.name)
            CounterUpdateWorker.perform_later(record, counter_name.to_s, reflection.name.to_s)
          end
        end
      end

      def self.valid_options
        [:async_counter_cache]
      end
    end

    # FIXME: Figure out how we make scopes less weird & async
    included do
      ActiveRecord::Associations::Builder::Association.extensions << AssociationBuilderExtension

      def self.async_counter_cache(counter_name, scope)
        define_method "refresh_#{counter_name}" do
          relation = instance_exec(&scope)
          new_count = relation.count

          return if self[counter_name] == new_count
          update_columns counter_name => new_count, :updated_at => Time.current
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, AsyncCounterCache::RailsIntegration
