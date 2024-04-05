# Run with `bundle exec ruby test/cms_test.rb`
# Used by Sinatra and Rack to know if the code is being tested
# Used by Sinatra to determine whether it will start a web 
# server or not (dont want to if we're running tests)
ENV["RACK_ENV"] = "test"

# Load Minitest and configure it to automatically run any tests
# that will be defined
require "minitest/autorun"
# Gives us access to Rack::Test helper methods
# Does not come built in with Sinatra
require "rack/test"
require "minitest/reporters"
Minitest::Reporters.use!
# Module contains a variety of useful methods for working with 
# files and paths. The names and functionality of the methods
# provided by this module are based on the names and options 
# of common shell commands.
require "fileutils"

# Require our Sinatra app
require_relative "../cms"

# Test class needs to subclass Minitest::Test class
class CMSTest < Minitest::Test
	# To access helper methods
  include Rack::Test::Methods

	# Methods expect a method called app to exist and return an 
	# instance of a Rack application when called
  def app
    Sinatra::Application
  end

	def setup
		FileUtils.mkdir_p(data_path) # Create a directory
	end

	def teardown
    FileUtils.rm_rf(data_path) # Delete directory and all its contents 
  end

	# Returns new File obejct
	def create_document(name, content = "")
		File.open(File.join(data_path, name), "w") do |file|
			file.write(content)
		end
	end

  def test_index
		create_document("about.md")
    create_document("changes.txt")

    get "/"
		# Assert the status code, content type header, and body 
		# of the response:
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
  end

	def test_viewing_text_doc
		create_document("history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.
			1995 - Ruby 0.95 released.")

		get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "Ruby 0.95 released")
	end

	def test_doc_not_found
		get "/notafile.ext"
		assert_equal(302, last_response.status) # Assert that the user was redirected

		# Request the page that the user was redirected to
		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "notafile.ext does not exist.")
		
		get "/"
		refute_includes(last_response.body, "notafile.ext does not exist.")
	end

	def test_viewing_md_doc
		create_document("about.md", "# Ruby is...")

		get "/about.md"
		assert_equal(200, last_response.status)
		assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
		assert_includes(last_response.body, "<h1>Ruby is...</h1>")
	end

	def test_editing_doc
		create_document("changes.txt", "some text")

		get "/changes.txt/edit"
		assert_equal(200, last_response.status)
		assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
		assert_includes(last_response.body, "<textarea")
		assert_includes(last_response.body,'<button type="submit"')
	end

	def test_updating_doc
		create_document("changes.txt", "some text")

		post "/changes.txt", content: "new content"
		assert_equal(302, last_response.status)

		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "changes.txt has been updated")

		get "/changes.txt"
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "new content")
	end

	def test_view_new_doc_form
		get "/new"
		assert_equal(200, last_response.status)
		assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
		assert_includes(last_response.body, "<input")
		assert_includes(last_response.body, '<button type="submit">')
	end

	def test_create_new_doc
		post "/create", filename: "test.txt"
		assert_equal(302, last_response.status)

		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "test.txt has been created.")

		get "/"
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "test.txt")
	end

	def test_create_empty_name_doc
		post "/create", filename: ""
		assert_equal(422, last_response.status)
		assert_includes(last_response.body, "A name is required.")
		assert_includes(last_response.body,'<button type="submit">')
	end

	def test_deleting_file
		create_document("test.txt")

		post "/test.txt/delete"
		assert_equal(302, last_response.status)

		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "test.txt has been deleted.")

		get "/"
		refute_includes(last_response.body, "test.txt")
	end

	def test_signin_form
		get "/"
		assert_includes(last_response.body, '<button type="submit">Sign In')

		get "/users/signin"
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, '<label for="username">')
		assert_includes(last_response.body, '<button type="submit">')
	end

	def test_valid_signing_in
		post "/users/signin", username: "admin", password: "secret"
		assert_equal(302, last_response.status)
		
		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "Welcome!")
		assert_includes(last_response.body, "Signed in as admin.")
		assert_includes(last_response.body, "Sign Out")

		get "/"
		refute_includes(last_response.body, "Welcome!")
	end

	def test_invalid_signing_in
		post "/users/signin", username: "admin", password: "invalid"
		assert_equal(422, last_response.status)
		assert_includes(last_response.body, "Invalid credentials")
		assert_includes(last_response.body, "admin")
		assert_includes(last_response.body, '<label for="username">')
		assert_includes(last_response.body, '<button type="submit">')

		get "/users/signin"
		refute_includes(last_response.body, "Invalid credentials")
	end

	def test_signout
		post "/users/signin", username: "admin", password: "secret"

		get last_response["Location"]
		assert_includes(last_response.body, "Sign Out")

		post "/users/signout"
		assert_equal(302, last_response.status)

		get last_response["Location"]
		assert_equal(200, last_response.status)
		assert_includes(last_response.body, "You have been signed out.")
		assert_includes(last_response.body, "Sign In")
	end
end