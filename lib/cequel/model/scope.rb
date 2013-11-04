module Cequel

  module Model

    class Scope < BasicObject

      include ::Enumerable

      def initialize(clazz, data_sets)
        @clazz, @data_sets = clazz, data_sets
        @index_preference_applied = false
      end

      def each(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block
          each_row do |row|
            result = hydrate(row)
            yield result if result
          end
        else
          return ::Enumerator.new do |y|
            self.each do |val|
              y.yield val
            end
          end
        end
      end

      def each_row(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block
          apply_index_preference!
          @data_sets.each do |data_set|
            data_set.each(&block)
          end
        else
          to_enum(:each_row)
        end
      end

      def find_in_batches(options = {})
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        unless ::Kernel.block_given?
          return to_enum(:find_in_batches, options)
        end
        find_rows_in_batches(options) do |batch|
          results = batch.map { |row| hydrate(row) }.compact
          yield results if results.any?
        end
      end

      def find_rows_in_batches(options = {}, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        return to_enum(:find_rows_in_batches, options) if block.nil?
        batch_size = options[:batch_size] || 1000
        apply_index_preference!
        @data_sets.each do |data_set|
          keys = lookup_keys(data_set)
          if keys
            find_rows_in_key_batches(data_set, keys, batch_size, &block)
          else
            find_rows_in_range_batches(data_set, batch_size, &block)
          end
        end
        nil
      end

      def find_each(options = {}, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        unless ::Kernel.block_given?
          return to_enum(:find_each, options)
        end
        find_in_batches(options) { |batch| batch.each(&block) }
      end

      def find_each_row(options = {}, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        unless ::Kernel.block_given?
          return to_enum(:find_each_row, options)
        end
        find_rows_in_batches(options) { |batch| batch.each(&block) }
      end

      def first
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        apply_index_preference!
        @data_sets.each do |data_set|
          row = hydrate(data_set.first)
          return row if row
        end
        nil
      end

      def count
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if restriction_columns == [@clazz.key_alias]
          ::Kernel.raise ::Cequel::Model::InvalidQuery,
            "Meaningless to perform count with key row restrictions"
        end
        apply_index_preference!
        @data_sets.inject(0) { |count, data_set| count + data_set.count }
      end

      def size
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        count
      end

      def length
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        to_a.length
      end

      def update_all(changes)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        keys = keys()
        unless keys.empty?
          @clazz.column_family.where(key_alias => keys).update(changes)
        end
      end

      def destroy_all
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        each { |instance| instance.destroy }
      end

      def delete_all
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if @data_sets.length == 1
          if @data_sets.first.row_specifications.length == 0
            return @data_sets.first.truncate
          end
        end
        keys = keys()
        if keys.empty?
          @data_sets.each { |data_set| data_set.delete }
        else
          @clazz.column_family.where(key_alias => keys).delete
        end
      end

      def find(*keys, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block then super
        else with_scope(self) { @clazz.find(*keys) }
        end
      end

      def any?(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block then super
        else count > 0
        end
      end

      def none?(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block then super
        else empty?
        end
      end

      def empty?
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        count == 0
      end

      def one?(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block then super
        else count == 1
        end
      end

      def keys
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        key_alias = @clazz.key_alias
        [].tap do |keys|
          @data_sets.each do |data_set|
            lookup_keys = lookup_keys(data_set)
            if lookup_keys
              keys.concat(lookup_keys)
              next
            end
            data_set.select!(key_alias).each { |row| keys << row[key_alias] }
          end
        end
      end

      def lookup_keys(data_set)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if data_set.row_specifications.length == 1
          specification = data_set.row_specifications.first
          if specification.respond_to?(:column)
            if specification.column == key_alias
              ::Kernel.Array(specification.value)
            end
          end
        end
      end

      def inspect
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        to_a.inspect
      end

      def ==(other)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        to_a == other.to_a
      end

      def select(*rows, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if block then super
        else scoped { |data_set| data_set.select(*rows) }.validate!
        end
      end

      def select!(*rows)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        scoped { |data_set| data_set.select!(*rows) }.validate!
      end

      def consistency(consistency)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        scoped { |data_set| data_set.consistency(consistency) }
      end

      def where(*row_specification)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if row_specification.length == 1 && ::Hash === row_specification.first
          row_specification.first.each_pair.inject(self) do |scope, (column, value)|
            scope.where_column_equals(column, value)
          end
        else
          scoped { |data_set| data_set.where(*row_specification) }
        end
      end

      def where!(*row_specification)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        scoped { |data_set| data_set.where!(*row_specification) }
      end

      def limit(*row_specification)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        scoped { |data_set| data_set.limit(*row_specification) }
      end

      def scoped(&block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        new_data_sets = @data_sets.map(&block)
        Scope.new(@clazz, new_data_sets)
      end

      def nil?
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        false # for ActiveSupport delegation
      end

      def method_missing(method, *args, &block)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if @clazz.respond_to?(method)
          @clazz.with_scope(self) do
            @clazz.__send__(method, *args, &block)
          end
        else
          super
        end
      end

      protected

      def validate!
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        columns = restriction_columns
        key_column = restriction_columns.include?(@clazz.key_alias)
        non_key_column = restriction_columns.any? do |column|
          column != @clazz.key_alias
        end
        if key_column
          if non_key_column
            ::Kernel.raise InvalidQuery,
              "Can't select by key and non-key columns in the same query"
          elsif key_only_select?
            ::Kernel.raise InvalidQuery,
              "Meaningless to select only key column with key row specification"
          end
        end
        self
      end

      def where_column_equals(column, value)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        if [] == value
          Scope.new(@clazz, [])
        elsif column.to_sym != @clazz.key_alias && ::Array === value
          new_data_sets = []
          @data_sets.each do |data_set|
            value.each do |element|
              new_data_sets << data_set.where(column => element)
            end
          end
          Scope.new(@clazz, new_data_sets)
        else
          scoped { |data_set| data_set.where(column => value) }
        end.validate!
      end

      private

      def find_rows_in_range_batches(data_set, batch_size)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        key_alias = @clazz.key_alias
        key_alias = key_alias.upcase if key_alias =~ /key/i
        scope = data_set.limit(batch_size)
        unless data_set.select_columns.empty? ||
          data_set.select_columns.include?(key_alias)

          scope = scope.select(key_alias)
        end

        batch_scope = scope
        last_key = nil
        begin
          batch_rows = batch_scope.to_a
          break if batch_rows.empty?
          if batch_rows.first[key_alias] == last_key
            yield batch_rows[1..-1]
          else
            yield batch_rows
          end
          last_key = batch_rows.last[key_alias]
          batch_scope =
            scope.where("? > ?", key_alias, last_key)
        end while batch_rows.length == batch_size
      end

      def find_rows_in_key_batches(data_set, keys, batch_size)
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        key_alias = @clazz.key_alias
        keys.each_slice(batch_size) do |key_slice|
          yield data_set.where!(key_alias => key_slice).to_a
        end
      end

      def key_only_select?
        key_only_select = @data_sets.all? do |data_set|
          data_set.select_columns == [@clazz.key_alias]
        end
      end

      def restriction_columns
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        [].tap do |columns|
          @data_sets.each do |data_set|
            data_set.row_specifications.each do |specification|
              if specification.respond_to?(:column)
                columns << specification.column
              end
            end
          end
        end
      end

      def hydrate(row)
        return if row.nil?
        key_alias = @clazz.key_alias.to_s
        key_alias = key_alias.upcase if key_alias =~ /^key$/i
        row.reject! { |k, v| v.nil? }
        if row.keys.any? && (key_only_select? || row.keys != [key_alias])
          @clazz._hydrate(row)
        end
      end

      def apply_index_preference!
        ::Kernel.puts ::Kernel.__method__ if $VERBOSE
        return if @index_preference_applied
        # XXX seems ugly to do the in-place sort here.
        preference = @clazz.index_preference_columns
        @data_sets.each do |data_set|
          data_set.row_specifications.sort! do |spec1, spec2|
            if spec1.respond_to?(:column) && spec2.respond_to?(:column)
              pref1 = preference.index(spec1.column)
              pref2 = preference.index(spec2.column)
              if pref1 && pref2 then pref1 - pref2
              elsif pref1 then -1
              elsif pref2 then 1
              else 0
              end
            else 0
            end
          end
        end
        @index_preference_applied = true
      end

    end
    
  end

end
