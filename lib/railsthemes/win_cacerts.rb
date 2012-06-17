# This is required on Windows to get around an issue where SSL certificates
# are not loaded properly on default
#
# originally from https://raw.github.com/gist/867550/win_fetch_cacerts.rb, from
# https://gist.github.com/867550

require 'net/http'

module Railsthemes
  class WinCacerts
    def self.fetch
      # create a path to the file "C:\RailsInstaller\cacert.pem"
      cacert_file = File.join(%w{c: RailsInstaller cacert.pem})

      Net::HTTP.start("curl.haxx.se") do |http|
        resp = http.get("/ca/cacert.pem")
        if resp.code == "200"
          open(cacert_file, "wb") { |file| file.write(resp.body) }
          `set SSL_CERT_FILE=C:\RailsInstaller\cacert.pem`
          puts `set SSL_CERT_FILE`
        else
          Safe.log_and_abort "A cacert.pem bundle could not be downloaded."
        end
      end
    end
  end
end
