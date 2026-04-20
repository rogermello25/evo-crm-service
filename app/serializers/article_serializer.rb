# frozen_string_literal: true

# ArticleSerializer - Optimized serialization for Article resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   ArticleSerializer.serialize(@article, include_author: true)
#
module ArticleSerializer
  extend self

  # Serialize single Article
  #
  # @param article [Article] Article to serialize
  # @param options [Hash] Serialization options
  # @option options [Boolean] :include_author Include author details
  #
  # @return [Hash] Serialized article ready for Oj
  #
  def serialize(article, include_author: false)
    result = {
      id: article.id,
      title: article.title,
      slug: article.slug,
      content: article.content,
      description: article.description,
      position: article.position,
      category_id: article.category_id,
      portal_id: article.portal_id,
      author_id: article.author_id,
      views: article.views,
      status: article.status,
      created_at: article.created_at&.iso8601,
      updated_at: article.updated_at&.iso8601
    }

    # Include author if loaded
    if include_author && article.association(:author).loaded?
      result[:author] = UserSerializer.serialize(article.author)
    end

    result
  end

  # Serialize collection of Articles
  #
  # @param articles [Array<Article>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized articles
  #
  def serialize_collection(articles, **options)
    return [] unless articles

    articles.map { |article| serialize(article, **options) }
  end
end
