class PurchasesController < ApplicationController
  before_action :require_student, only: [:index]
  before_action :require_admin, only: [:student_purchases, :course_purchases]  
  before_action :require_student_login, only: [:new, :create]
  before_action :require_credit_card, only: [:new, :create]
  before_action :set_purchase, only: [:show, :destroy]
  before_action :require_owner, only: [:delete]
  before_action :require_admin_or_owner, only: [:show]

  # GET /purchases
  # GET /purchases.json
  def index
    @purchases = Purchase.where(student_id: current_user.id)
  end

  # GET students/:student_id/purchases
  def student_purchases
    @student = Student.find(params[:student_id])
    @purchases = @student.purchases
  end

  # GET courses/:course_id/purchases
  def course_purchases
    @course = Course.find(params[:course_id])
    @purchases = @course.purchases
  end

  # GET /purchases/1
  # GET /purchases/1.json
  def show
  end

  # GET /purchases/new
  def new
    @purchase = Purchase.new
  end

  # POST /purchases
  # POST /purchases.json
  def create
    @errors = []
    @compiled = []
    otp = params[:otp]
    totp = ROTP::TOTP.new(session[:secret_key])
    #Must be verified within 30 seconds
    respond_to do |format|

      unless totp.verify(otp, drift_behind: 30).nil?
        current_user.cart.cart_items.each do |cart_item|
          @purchase = current_user.purchases.build()
          @purchase.student = current_user
          @purchase.section = cart_item.section
          @purchase.price = cart_item.section.course.price
          unless @purchase.save
            @errors.append @purchase.errors
          else
            @compiled.append @purchase
            message = PurchaseMailer.enrollment_email(cart_item.section.teacher, current_user, cart_item.section).deliver!
            cart_item.destroy
          end
        end

        if @compiled.any?
          message = PurchaseMailer.purchase_email(current_user_auth, @compiled).deliver!
        end

        unless @errors.any?
          format.html { redirect_to purchases_url, notice: 'Purchase was successfully created.' }
          format.json { render :show, status: :created, location: purchases_url }
        else
          format.html { render :new  }
          format.json { render json: @errors, status: :unprocessable_entity }
        end

      else
        format.html { redirect_to cart_path, notice: 'Incorrect password.  Purchase declined.' }
        format.json { head :no_content }
      end
    end
  end

  # DELETE /purchases/1
  # DELETE /purchases/1.json
  def destroy
    @purchase.destroy
    respond_to do |format|
      format.html { redirect_to purchases_url, notice: 'Purchase was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def generate_otp
    session[:secret_key] = ROTP::Base32.random
    totp = ROTP::TOTP.new(session[:secret_key])
    message = PurchaseMailer.otp_email(current_user_auth, totp.now).deliver!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_purchase
      @purchase = Purchase.find(params[:id])
    end

    def is_owner?
      is_student_login? and current_user.id == @purchase.student.id
    end

    def require_owner
      unless is_owner?
        redirect_to home_url, notice: NOT_AUTHORIZED
      end 
    end

    def require_admin_or_owner
      unless is_admin_login? or is_owner_logged_in?
        redirect_to home_url, notice: NOT_AUTHORIZED
      end
    end

    def require_credit_card
      if current_user.credit_card.nil?
        redirect_to edit_student_url(current_user.id), notice: 'Need to add credit card to make purchase'
      end
    end
end
