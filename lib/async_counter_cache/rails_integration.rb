module AsyncCounterCache
  class CounterUpdateWorker < ActiveJob::Base
    def perform(record, counter_name)
      record.public_send("_update_#{counter_name}")
    end
  end

  module RailsIntegration
    extend ActiveSupport::Concern

    module AssociationBuilderExtension
      def self.build(model, reflection)
        counter_name = reflection.options[:async_counter_cache]
        return unless counter_name.present?

        model.send(:define_method, "_update_#{counter_name}") do
          new_count = public_send(reflection.name).count
          return if self[counter_name] == new_count
          update! counter_name => new_count
        end

        model.after_commit do
          next if self.destroyed?
          CounterUpdateWorker.perform_later(self, counter_name.to_s)
        end

        if reflection.has_inverse?
          reflection.klass.after_commit do
            record = self.public_send(reflection.inverse_of.name)
            next if record.destroyed?
            CounterUpdateWorker.perform_later(record, counter_name.to_s)
          end
        end
      end

      def self.valid_options
        [:async_counter_cache]
      end
    end

    included do
      ActiveRecord::Associations::Builder::Association.extensions << AssociationBuilderExtension

      def self.async_counter_cache(counter_name, scope)
        define_method "refresh_#{counter_name}" do
          CounterUpdateWorker.perform_later(self, counter_name.to_s)
        end

        define_method "_update_#{counter_name}" do
          new_count = instance_exec(&scope).count
          return if self[counter_name] == new_count
          update! counter_name => new_count
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, AsyncCounterCache::RailsIntegration
