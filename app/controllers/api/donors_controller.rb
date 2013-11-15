class Api::DonorsController < Api::BaseController
  skip_before_filter :require_authentication, :only => :create

  def create
    donor = Donor.new(params[:donor])
    donor.type_donor = "registered"
    donor.password = secure_password(params[:donor][:password])

    respond_to do |format|
      if donor.save
        format.json { render json: donor, status: :created }
      else
        format.json { render json: donor.errors, status: :unprocessable_entity }
      end
    end
  end

  def balance_information
    if current_donor.donations.empty?
      render json: { :donor_current_balance => "0.0" }.to_json
    else
      share_balance = BigDecimal("#{current_donor.donations.sum(:shares_added)}") - BigDecimal("#{current_donor.charity_grants.sum(:shares_subtracted)}")
      donor_current_balance = ((BigDecimal("#{share_balance}") * BigDecimal("#{Share.last.donation_price}")) * 10).ceil / 10.0
      donor_total_donations = current_donor.donations.sum(:gross_amount)
      donor_total_grants = current_donor.charity_grants.where("status = ?", 'sent').sum(:gross_amount)
      giv2giv_share_balance = BigDecimal("#{donations.sum(:shares_added)}") - BigDecimal("#{charity_grants.sum(:shares_subtracted)}")
      giv2giv_current_balance = ((BigDecimal("#{giv2giv_share_balance}") * BigDecimal("#{Share.last.donation_price}")) * 10).ceil / 10.0
      giv2giv_total_donations = donations.sum(:gross_amount)
      giv2giv_total_grants = charity_grants.where("status = ?", 'sent').sum(:gross_amount)
      render json: { :donor_current_balance => donor_current_balance, :donor_total_donations => donor_total_donations, :donor_total_grants => donor_total_grants, :giv2giv_current_balance => giv2giv_current_balance, :giv2giv_total_donations => giv2giv_total_donations, :giv2giv_total_grants => giv2giv_total_grants }.to_json
    end
  end

  def subscriptions
    subscriptions = current_donor.donor_subscriptions
    subscriptions_list = []
    subscriptions.each do |subscription|
      #Better to include Endowment.where("endowment_id = ?", subscription.endowment_id).my_balances and endowment.global_balances
      subscriptions_hash = [ subscription.stripe_subscription_id => {
        "endowment_name" => subscription.endowment.name,
        "endowment_donation_amount" => subscription.gross_amount,
        "endowment_donor_count" => Donation.where("endowment_id = ?", subscription.endowment_id).count('donor_id', :distinct => true),
        "endowment_donor_total_donations" => current_donor.donations.where("endowment_id = ?", subscription.endowment_id).sum(:gross_amount),
        "endowment_total_donations" => Donation.where("endowment_id = ?", subscription.endowment_id).sum(:gross_amount),
        "endowment_donor_current_balance" => ((BigDecimal(current_donor.donations.where("endowment_id = ?", subscription.endowment_id).sum(:shares_added)) - BigDecimal(current_donor.charity_grants.sum(:shares_subtracted))) * Share.last.grant_price * 10).ceil / 10.0,
        "endowment_total_balance" => ((BigDecimal(Donation.where("endowment_id = ?", subscription.endowment_id).sum(:shares_added)) - BigDecimal(CharityGrant.sum(:shares_subtracted))) * Share.last.grant_price * 10).ceil / 10.0,
        "total_granted_by_donor" => current_donor.charity_grants.where("status = ?", 'sent').where("endowment_id = ?", subscription.endowment_id).sum(:grant_amount),
        "total_granted_from_endowment" => CharityGrant.where("status = ?", 'sent').where("endowment_id = ?", subscription.endowment_id).sum(:grant_amount)
      }
      ]
      subscriptions_list << subscriptions_hash
    end
    render json: subscriptions_list
  end

  def update
    donor = current_donor

    respond_to do |format|
      if donor && donor.update_attributes(params[:donor])
        format.json { render json: donor }
      else
        format.json { render json: donor.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    respond_to do |format|
      format.json { render json: current_donor }
    end
  end

  # def endowments
  #   endowments = current_donor.endowments
  #   render json: endowments
  # end
end
