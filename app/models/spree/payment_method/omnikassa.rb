module Spree
  class PaymentMethod::Omnikassa < PaymentMethod
    def actions
      %w{capture}
    end

    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    def capture(payment)
      #payments with state "checkout" must be moved into state "pending" first:
      payment.update_attribute(:state, "pending") if payment.state == "checkout"
      payment.complete
      true
    end

    def url
      if self.environment == "production"
        "https://payment-webinit.omnikassa.rabobank.nl"
      else
        "https://payment-webinit.simu.omnikassa.rabobank.nl/paymentServlet"
      end
    end
  end
end
