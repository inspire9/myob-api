require 'base64'
require 'oauth2'

module Myob
  module Api
    class Client
      include Myob::Api::Helpers

      attr_reader :current_company_file, :client

      def initialize(options)
        Myob::Api::Model::Base.descendants.each do |klass|
          model klass.name.split("::").last
        end

        @redirect_uri         = options[:redirect_uri]
        @consumer             = options[:consumer]
        @access_token         = options[:access_token]
        @refresh_token        = options[:refresh_token]
        @current_company_file = options[:selected_company_file] || {}
        @client               = OAuth2::Client.new(@consumer[:key], @consumer[:secret], {
          :site          => 'https://secure.myob.com',
          :authorize_url => '/oauth2/account/authorize',
          :token_url     => '/oauth2/v1/authorize',
        })

        if options[:company_file]
          @current_company_file = select_company_file(options[:company_file])
        end
      end

      def get_access_code_url(params = {})
        @client.auth_code.authorize_url(params.merge(scope: 'CompanyFile', redirect_uri: @redirect_uri))
      end

      def get_access_token(access_code)
        @token         = @client.auth_code.get_token(access_code, redirect_uri: @redirect_uri)
        @access_token  = @token.token
        @expires_at    = @token.expires_at
        @refresh_token = @token.refresh_token
        @token
      end

      def headers
        token = @current_company_file[:token]
        if token.nil? || token == ''
          # if token is blank assume we are using federated login - http://myobapi.tumblr.com/post/109848079164/2015-1-release-notes
          {
            'x-myobapi-key'     => @consumer[:key],
            'x-myobapi-version' => 'v2',
            'Content-Type'      => 'application/json'
          }
        else
          {
            'x-myobapi-key'     => @consumer[:key],
            'x-myobapi-version' => 'v2',
            'x-myobapi-cftoken' => token,
            'Content-Type'      => 'application/json'
          }
        end
      end

      def select_company_file(company_file)
        company_file_id = (company_files.find {|file| file['Name'] == company_file[:name]} || [])['Id']
        if company_file_id
          token = company_file[:token]
          if (token.nil? || token == '') && !company_file[:username].nil? && company_file[:username] != '' && !company_file[:password].nil?
            # if we have been given login details, encode them into a token
            token = Base64.encode64("#{company_file[:username]}:#{company_file[:password]}")
          end
          @current_company_file = {
            :id    => company_file_id,
            :token => token
          }
        end
      end

      def connection
        if @refresh_token
          @auth_connection ||= OAuth2::AccessToken.new(@client, @access_token, {
            :refresh_token => @refresh_token
          }).refresh!
        else
          @auth_connection ||= OAuth2::AccessToken.new(@client, @access_token)
        end
      end

      private
      def company_files
        @company_files ||= self.company_file.all.to_a
      end
    end
  end
end
