module Myob
  module Api
    module Model
      class ServiceInvoice < Base
        def model_route
          'Sale/Invoice/Service'
        end
      end
    end
  end
end
