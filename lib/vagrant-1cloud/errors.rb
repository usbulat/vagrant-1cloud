module VagrantPlugins
  module OneCloud
    module Errors
      class OneCloudError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_1cloud.errors")
      end

      class APIStatusError < OneCloudError
        error_key(:api_status)
      end

      class JSONError < OneCloudError
        error_key(:json)
      end

      class ResultMatchError < OneCloudError
        error_key(:result_match)
      end

      class CertificateError < OneCloudError
        error_key(:certificate)
      end

      class PublicKeyError < OneCloudError
        error_key(:public_key)
      end

      class RsyncError < OneCloudError
        error_key(:rsync)
      end
    end
  end
end
