# Run with `ruby cms.rb` / `bundle exec ruby cms.rb`
require "sinatra"
require "sinatra/reloader"
# require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  # set :erb, :escape_html => true
end

# Return string path of data based on environment
# Methods defined in global scope
def data_path
	# root = File.expand_path("..", __FILE__) # Get root path tha the file is currently in
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# Returns rendered HTML from markdown formatted text
def render_markdown(text)
	markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
	markdown.render(text)
end

# Returns string file contents from path
# "Content-Type" header
def load_file_content(path)
  content = File.read(path)
	case File.extname(path)
	when ".txt"
		headers["Content-Type"] = "text/plain"
		content
	when ".md"
		erb render_markdown(content)
	end
end

# Return true if user is signed in
def user_signed_in?
	session[:username]
	# session.key?(:username)
end

# Redirect user if not signed in
def require_signed_in_user
	if !session[:username]
		session[:message] = "You must be signed in to do that."
		redirect "/"
	end
end

# Return hash of valid users
def load_user_credentials
	users_path = ""
  if ENV["RACK_ENV"] == "test"
    users_path = File.expand_path("../test/users.yml", __FILE__)
  else
    users_path = File.expand_path("../users.yml", __FILE__)
  end
	YAML.load_file(users_path)
end

# Return true if user credentials are valid
def valid_user?(username, password)
	users = load_user_credentials
	if users[username]
		return BCrypt::Password.new(users[username]) == password
	end
	false
end

# View list of files 
get "/" do
	pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

# Create new document
get "/new" do
	if !session[:username]
		session[:message] = "You must be signed in to do that."
		redirect "/"
	end
	erb :new
end

# Add new document to file list
post "/create" do
	require_signed_in_user
	file_name = params[:filename].to_s.strip
	if file_name.empty? || File.extname(file_name).empty?
		session[:message] = "A name is required."
		status 422
		erb :new
	else
		file_path = File.join(data_path, file_name)
		File.write(file_path, "")
		session[:message] = "#{file_name} has been created."
		redirect "/"
	end
end

# View file
get "/:filename" do
	file_path = File.join(data_path, params[:filename])
	if File.file?(file_path)
		load_file_content(file_path)
	else
		session[:message] = "#{params[:filename]} does not exist."
		redirect "/"
	end
end

# Edit a file 
get "/:filename/edit" do
	require_signed_in_user
	@file_name = params[:filename]
	file_path = File.join(data_path, @file_name)
	@content = File.read(file_path)
	erb :edit
end 

# Change a file 
post "/:filename" do 
	require_signed_in_user
	edited_content = params[:content]
	file_name = params[:filename]
	file_path = File.join(data_path, file_name)
	File.write(file_path, edited_content)
	session[:message] = "#{file_name} has been updated."
	redirect "/"
end

# Delete a file
post "/:filename/delete" do 
	require_signed_in_user
	file_name = params[:filename]
	file_path = File.join(data_path, file_name)
	File.delete(file_path)
	session[:message] = "#{file_name} has been deleted."
	redirect "/"
end

# Sign in user
get "/users/signin" do
	erb :signin
end

# Validate user
post "/users/signin" do
	username = params[:username]
	password = params[:password]
	if valid_user?(username, password)
		session[:username] = username
		session[:message] = "Welcome!"
		redirect "/"
	else
		session[:message] = "Invalid credentials"
		status 422
		erb :signin
	end
end

# Sign out user
post "/users/signout" do
	session.delete(:username)
	session[:message] = "You have been signed out."
	redirect "/"
end