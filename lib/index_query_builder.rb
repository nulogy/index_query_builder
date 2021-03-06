require "active_support/core_ext/string"

require "index_query_builder/query_definition"
require "index_query_builder/query_builder"
require "index_query_builder/version"

# Simple DSL for building queries using filters.
#
# This module makes it easy to fetch records from the database, specially
# for showing and filtering records in an index page
#
module IndexQueryBuilder

  # Builds a query by calling arel methods on base_scope
  #
  # @param base_scope [Arel] used to build query on top of this scope
  # @param options [Hash]
  # @option :with [Hash] filters used to build query. Key is filter name, value is value for the filter
  # @yield [QueryDefinition] Gives a QueryDefinition object that implements a DSL to define how to apply filters
  # @return [Arel] returns arel object to make it easy to extend query (e.g. add pagination, etc)
  #
  # ==== Example
  #
  #   posts = IndexQueryBuilder.query Post.where(:user_id => user.id), with: { title: 'DSLs are awesome' } do |query|
  #     query.filter_field :posted
  #     query.filter_field :title, contains: :title
  #     query.filter_field :posted_date,
  #       greater_than_or_equal_to: :from_posted_date, less_than: :to_posted_date
  #     query.filter_field [:comments, :author, :name], equal_to: :comment_author_name
  #
  #     query.order_by "posted_date DESC, posts.created_at DESC"
  #   end
  def self.query(base_scope, options={}, &block)
    query_definition = QueryDefinition.new
    block.call(query_definition)

    QueryBuilder.apply(base_scope, query_definition, filters(options))
  end

  # Builds a query by calling arel methods on base_scope, but it returns children of base scope.
  # Use this method when using same filters as when querying the parent, but want to get back all children instead.
  # This way, you can reuse same query definition you used for IndexQueryBuilder.query.
  #
  # @param child_association [Symbol] children's association name
  # @param base_scope [Arel] used to build query on top of this scope
  # @param options [Hash]
  # @option options [Hash] :with filters used to build query. Key is filter name, value is value for the filter
  # @yield [QueryDefinition] Gives a QueryDefinition object that implements a DSL to define how to apply filters
  # @return [Arel] returns arel object to make it easy to extend query (e.g. add pagination, etc)
  #
  # ==== Example
  #
  #   comments = IndexQueryBuilder.query_children :comments, Comments, with: { title: 'DSLs are awesome' } do |query|
  #     query.filter_field :posted
  #     query.filter_field :title, contains: :title
  #     query.filter_field :posted_date,
  #       greater_than_or_equal_to: :from_posted_date, less_than: :to_posted_date
  #     query.filter_field [:comments, :author, :name], equal_to: :comment_author_name
  #
  #     query.order_by "comment_date DESC"
  #   end
  def self.query_children(child_association, base_scope, options={}, &block)
    parents = query(base_scope.eager_load(child_association), options, &block)

    children_of(parents, child_association, base_scope)
  end

  # Exception raised when using Unknown Operator in query definition.
  #
  # ==== Example
  #
  # IndexQueryBuilder.query Post.where(nil) do |query|
  #   query.filter_field :view_count, unkown_operator: :view_count
  # end
  #
  # will raise this exception.
  #
  class UnknownOperator < ArgumentError; end

  private

  def self.filters(params)
    symbolize_keys(params.fetch(:with) { {} })
  end

  def self.symbolize_keys(params)
    Hash[params.map { |key, value| [key.to_sym, value] }]
  end

  def self.children_of(parents, child_association, base_scope)
    initialize_parent_association(child_association, base_scope, parents).flat_map(&child_association)
  end

  def self.initialize_parent_association(child_association, base_scope, parents)
    parents.each do |parent|
      parent.public_send(child_association).each do |child|
        child.public_send("#{base_scope.name.underscore}=", parent)
      end
    end
  end
end
