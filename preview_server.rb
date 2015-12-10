require 'active_support'
require 'cgi'
require 'json'
require 'sequel'

class PreviewServer
  DB = Sequel.connect(ENV['DATABASE_URL'])

  def call(env)
    request = Rack::Request.new(env)
    website_id, branch_hash = request.host.split('.').first.split('-')

    return response(422, 'Invalid Request') unless website_id.match(/\A\d{1,9}\z/) && branch_hash.match(/\A[0-9a-f]{40}\z/)
    return response(401, 'Not Authorized') unless authorized?(env['HTTP_COOKIE'], website_id, branch_hash)

    website_path = "/websites/#{website_id}/#{branch_hash}/_site"
    return response(404, 'Website Not Found') unless File.directory?(website_path)

    webpage_path = website_path + (['/', ''].include?(request.path_info) ? '/index.html' : request.path_info)
    return response(404, 'Webpage Not Found') unless File.file?(webpage_path)

    [200, {'Content-Type' => Rack::Mime.mime_type(::File.extname(webpage_path), 'text/html')}, [File.read(webpage_path)]]
  end

  private

  def authorized?(http_cookie, website_id, branch_hash)
    raw_session = http_cookie.to_s.split(';').map(&:strip).find { |c| c.match(/\A_static_website_manager_session=/) }

    if raw_session
      session_value = CGI.unescape(raw_session.sub(/\A_static_website_manager_session=/, '')) rescue ''

      if session_value.length > 0
	key_generator = ActiveSupport::KeyGenerator.new(ENV['SECRET_KEY_BASE'], iterations: 1000)
	secret = key_generator.generate_key('encrypted cookie')
	sign_secret = key_generator.generate_key('signed encrypted cookie')
	encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, serializer: JSON)
	session = encryptor.decrypt_and_verify(session_value) rescue nil

	if session
	  user = DB[:users].join(:authorizations, user_id: :id).where(session_token: session['authentication'], website_id: website_id).first
	  # TODO: authorize branch access
	  !!user
	end
      end
    end
  end

  def response(status = 200, body)
    [status, {'Content-Type' => 'text/html'}, [body]]
  end
end
