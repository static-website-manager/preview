class PreviewServer
  def call(env)
    request = Rack::Request.new(env)
    website_id, branch_hash = request.host.split('.').first.split('-')

    if website_id.match(/\A\d{1,9}\z/) && branch_hash.match(/\A[0-9a-f]{40}\z/)
      website_path = "/websites/#{website_id}/#{branch_hash}/_site"

      if File.directory?(website_path)
        if request.path_info.empty? || request.path_info.match(/\/\z/)
          webpage_path = "#{website_path}/#{request.path_info + 'index.html'}"
        else
          webpage_path = "#{website_path}/#{request.path_info}"
        end

        if File.file?(webpage_path)
          [200, {'Content-Type' => Rack::Mime.mime_type(::File.extname(webpage_path), 'text/html')}, [File.read(webpage_path)]]
        else
          [404, {'Content-Type' => 'text/html'}, ["Webpage Not Found - #{webpage_path}"]]
        end
      else
        [404, {'Content-Type' => 'text/html'}, ["Website Not Found (2) - #{website_path}"]]
      end
    else
      [404, {'Content-Type' => 'text/html'}, ["Website Not Found (1) - #{website_id} ; #{branch_hash}"]]
    end
  end
end
