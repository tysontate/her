# encoding: utf-8
require File.join(File.dirname(__FILE__), "spec_helper.rb")

describe Her::API do
  context "initialization" do
    describe ".setup" do
      it "creates a default connection" do # {{{
        Her::API.setup :base_uri => "https://api.example.com"
        Her::API.default_api.base_uri.should == "https://api.example.com"
      end # }}}
    end

    describe "#setup" do
      it "sets a base URI" do # {{{
        @api = Her::API.new
        @api.setup :base_uri => "https://api.example.com"
        @api.base_uri.should == "https://api.example.com"
      end # }}}
    end

    describe "#request" do
      it "makes HTTP requests" do # {{{
        FakeWeb.register_uri(:get, "https://api.example.com/foo", :body => "Foo, it is.")

        class Foo < Faraday::Response::Middleware
          def on_complete(env)
            env[:body] = { :data => env[:body] }
          end
        end

        @api = Her::API.new
        @api.setup :base_uri => "https://api.example.com", :parse_middleware => Foo
        parsed_data = @api.request(:_method => :get, :_path => "/foo")
        parsed_data[:data] == "Foo, it is."
      end # }}}

      it "parses a request with the default parser" do # {{{
        FakeWeb.register_uri(:get, "https://api.example.com/users/1", :body => MultiJson.dump({ :id => 1, :name => "George Michael Bluth", :errors => ["This is a single error"], :metadata => { :page => 1, :per_page => 10 } }))

        @api = Her::API.new
        @api.setup :base_uri => "https://api.example.com"
        parsed_data = @api.request(:_method => :get, :_path => "users/1")
        parsed_data[:data].should == { :id => 1, :name => "George Michael Bluth" }
        parsed_data[:errors].should == ["This is a single error"]
        parsed_data[:metadata].should == { :page => 1, :per_page => 10 }
      end # }}}

      it "parses a request with a custom parser" do # {{{
        FakeWeb.register_uri(:get, "https://api.example.com/users/1", :body => MultiJson.dump(:id => 1, :name => "George Michael Bluth"))

        class CustomParser < Faraday::Response::Middleware
          def on_complete(env)
            json = JSON.parse(env[:body], :symbolize_names => true)
            errors = json.delete(:errors) || []
            metadata = json.delete(:metadata) || {}
            env[:body] = {
              :data => json,
              :errors => errors,
              :metadata => metadata,
            }
          end
        end

        @api = Her::API.new
        @api.setup :base_uri => "https://api.example.com" do |connection|
          connection.swap Her::Middleware::DefaultParseJSON, CustomParser
        end
        parsed_data = @api.request(:_method => :get, :_path => "users/1")
        parsed_data[:data].should == { :id => 1, :name => "George Michael Bluth" }
        parsed_data[:errors].should == []
        parsed_data[:metadata].should == {}
      end # }}}
    end
  end
end
