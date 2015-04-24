module AsyncCounterCache
  module Rails
    module AssociationReflection
      def counter_cache_column
        if options[:async_counter_cache] == true
          "#{active_record.name.demodulize.underscore.pluralize}_count"
        elsif options[:async_counter_cache]
          options[:async_counter_cache].to_s
        else
          super
        end
      end
    end

    module HasManyAssociation
      def cached_counter_attribute_name(reflection = reflection())
        if reflection.options[:async_counter_cache]
          reflection.options[:async_counter_cache].to_s
        else
          super
        end
      end
    end

    module AssociationBuilder
      def self.valid_options
        super + [:async_counter_cache]
      end
    end
  end
end

class ActiveRecord::Reflection::AssociationReflection# < MacroReflection
  prepend AsyncCounterCache::Rails::AssociationReflection
end

class ActiveRecord::Associations::HasManyAssociation# < CollectionAssociation
  prepend AsyncCounterCache::Rails::HasManyAssociation
end

class ActiveRecord::Associations::Builder::BelongsTo# < SingularAssociation
  prepend AsyncCounterCache::Rails::AssociationBuilder
end

class ActiveRecord::Associations::Builder::HasMany# < CollectionAssociation
  prepend AsyncCounterCache::Rails::AssociationBuilder
end
