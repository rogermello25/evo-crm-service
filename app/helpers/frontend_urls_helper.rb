module FrontendUrlsHelper
  def frontend_url(path, **query_params)
    url_params = query_params.blank? ? '' : "?#{query_params.to_query}"
    host = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
    host = "#{host}/" unless host.end_with?('/')
    "#{host}#{path}#{url_params}"
  end
end
