module Spree
  class OmnikassaPaymentsController < ApplicationController
    skip_before_filter :verify_authenticity_token

    def homecoming
      @payment_response = payment_response_from_params(params)
      @order = @payment_response.order

      if not @payment_response.valid?
        flash[:error] = "Invalid request"
        redirect_to(root_url) and return
      end

      case @payment_response.response_level
      when :success
        flash[:info] = "Success!"
      when :pending
        flash[:info] = "Still pending. You will recieve a message"
      when :cancelled
        flash[:error] = "Order cancelled"
      when :failed
        flash[:error] = "Error occurred"
      else
        flash[:error] = "Unknown Error occurred"
      end

      session[:order_id] = nil

      redirect_to(root_url) and return
    end

    def reply
      @payment_response = payment_response_from_params(params)
      @order = @payment_response.order
      add_payment_if_not_exists
      message = "OmnikassaPaymentResponse posted: payment: # @payment_response.payment.id}; params: #{params.inspect}"

      if @payment_response.valid?
        case @payment_response.response_level
        when :success
          Rails.logger.info message
          @payment_response.payment.complete!
          advance_order_status :complete
        when :pending
          Rails.logger.info message
          @payment_response.payment.pend!
          advance_order_status :payment
        when :cancelled
          Rails.logger.info message
          @payment_response.payment.failure!
          @payment_response.order.cancel
        when :failed
          Rails.logger.error message
          @payment_response.payment.failure!
          @payment_response.order.cancel
        else
          Rails.logger.error message
          @payment_response.payment.pend!
          @payment_response.order.cancel
        end
      else
        Rails.logger.error message
        @payment_response.payment.pend!
      end
      render :text => @payment_response.response_level.to_s
    end

    private
    def advance_order_status upto_state
      @order.update_attribute(:state, upto_state.to_s)
      session[:order_id] = nil # Usually checkout_controllers after_complete is called, setting session[:order_id] to nil
      @order.finalize!
    end

    # Adds a payment to order if order has no payments yet. 
    # Allows both homecoming and reply to create a payment, but avoids having two payments.
    def add_payment_if_not_exists
      if @order.payments.empty?
        p = Spree::Payment.new
        p.amount         = @order.total
        p.payment_method = Spree::PaymentMethod::Omnikassa.fetch_payment_method
        p.response_code  = @payment_response.attributes[:response_code]
        p.source         = @payment_response.payment_method
        p.order_id       = @order.id
        p.save!
        p.started_processing!
      end
    end

    def payment_response_from_params params
      Spree::OmnikassaPaymentResponse.new(params["Seal"], params["Data"])
    end
  end
end


