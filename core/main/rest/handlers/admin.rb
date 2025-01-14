#
# Copyright (c) 2006-2022 Wade Alcorn - wade@bindshell.net
# Browser Exploitation Framework (BeEF) - http://beefproject.com
# See the file 'doc/COPYING' for copying permission
#

module BeEF
  module Core
    module Rest
      class Admin < BeEF::Core::Router::Router

        config = BeEF::Core::Configuration.instance
        time_since_last_failed_auth = 0


        before do
          # error 401 unless params[:token] == config.get('beef.api_token')
          halt 401 if not BeEF::Core::Rest.permitted_source?(request.ip)

          # halt if requests are inside  beef.restrictions.api_attempt_delay
          if time_since_last_failed_auth != 0
            halt 401 if not BeEF::Core::Rest.timeout?('beef.restrictions.api_attempt_delay',
                                                      time_since_last_failed_auth,
                                                      lambda { |time| time_since_last_failed_auth = time})
          end

          headers 'Content-Type' => 'application/json; charset=UTF-8',
                  'Pragma' => 'no-cache',
                  'Cache-Control' => 'no-cache',
                  'Expires' => '0'
        end

        # @note Authenticate using the config set username/password to retrieve the "token" used for subsquent calls.
        # Return the secret token used for subsquene tAPI calls.
        #
        # Input must be specified in JSON format
        #
        # +++ Example: +++
        #POST /api/admin/login HTTP/1.1
        #Host: 127.0.0.1:3000
        #Content-Type: application/json; charset=UTF-8
        #Content-Length: 18
        #
        #{"username":"beef", "password":"beef"}
        #===response (snip)===
        #HTTP/1.1 200 OK
        #Content-Type: application/json; charset=UTF-8
        #Content-Length: 35
        #
        #{"success":"true","token":"122323121"}
        #
        post '/login' do
          request.body.rewind
          begin
            data = JSON.parse request.body.read
            # check username and password
            if not (data['username'].eql? config.get('beef.credentials.user') and data['password'].eql? config.get('beef.credentials.passwd') )
              if not data['password'].eql? "broken_pass"
                BeEF::Core::Logger.instance.register('Authentication', "User with ip #{request.ip} has failed to authenticate in the application.")
              end

              # failed attempts
              time_since_last_failed_auth = Time.now()
              halt 401
            else
              { "success" => true,
                "token" => "#{config.get('beef.api_token')}"
              }.to_json
            end
          rescue => e
            error 400
          end
        end

        private

      end
    end
  end
end
