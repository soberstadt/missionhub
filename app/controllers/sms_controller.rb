class SmsController < ApplicationController
  skip_before_filter :authenticate_user!, :verify_authenticity_token
  def mo
    # See if this is a sticky session ( prior sms in the past 1 hour )
    @text = ReceivedSms.where(sms_params.slice(:phone_number)).order('updated_at desc').where(["updated_at > ?", 1.hour.ago]).last
    if @text
      keyword = @text.sms_keyword
      if keyword
        if params[:message].split(' ').first.downcase == 'i'
          # We're getting into a sticky session
          # Find the last received sms from this phone number and send them the first question off the survey
          send_next_survey_question(keyword, @text.person, @text.phone_number)
        else
          # Find the person, save the answer, send the next question
          save_survey_question(keyword, @text.person, params[:message])
          send_next_survey_question(keyword, @text.person, @text.phone_number)
        end
      end
    else
      # Look for a previous response by this number
      @text = ReceivedSms.where(sms_params.slice(:phone_number, :message)).first
      if @text
        @text.update_attributes(sms_params)
      else
        @text = ReceivedSms.create!(sms_params)
        # If we already have a person with this phone number associate it with this SMS
        unless person = Person.includes(:phone_numbers).where('phone_numbers.number' => sms_params[:phone_number]).first
          # Create a person record for this phone number
          person = Person.new
          person.save(:validate => false)
          person.phone_numbers.create!(:number => sms_params[:phone_number], :location => 'mobile')
        end
        @text.update_attribute(:person_id, person.id)
      end
      @text.increment!(:response_count)
      keyword = SmsKeyword.find_by_keyword(params[:message].split(' ').first.downcase)
      
      if !keyword || !keyword.active?
        msg = t('ma.sms.keyword_inactive')
      else
        msg =  keyword.initial_response.sub(/\{\{\s*link\s*\}\}/, "http://#{request.host_with_port}/m/#{Base62.encode(@text.id)}")
        @text.update_attribute(:sms_keyword_id, keyword.id)
      end

      carrier = SmsCarrier.find_or_create_by_moonshado_name(@text.carrier)
      sms_id = SMS.deliver(sms_params[:phone_number], msg).first
      carrier.increment!(:sent_sms)
      sent_via = 'moonshado'
      SentSms.create!(:message => msg, :recipient => params[:device_address], :moonshado_claimcheck => sms_id, :sent_via => sent_via, :recieved_sms_id => @text.id)
    end
    render :text => @text.inspect
  end
  
  protected 
    def sms_params
      unless @sms_params
        @sms_params = params.slice(:carrier, :message, :country)
        @sms_params[:phone_number] = params[:device_address]
        @sms_params[:shortcode] = params[:inbound_address]
        @sms_params[:received_at] = DateTime.strptime(params[:timestamp], '%m/%d/%Y %H:%M:%S')
      end
      @sms_params
    end
    
    def send_next_survey_question(keyword, person, phone_number)
      question = next_question(keyword, person)
      if question
        msg = 'Please answer the following question: ' + question.label
        sms_id = SMS.deliver(phone_number, msg).first
        SentSms.create!(:message => msg, :recipient => phone_number, :moonshado_claimcheck => sms_id, :sent_via => 'moonshado', :recieved_sms_id => @text.id)
      end
    end
    
    def save_survey_question(keyword, person, answer)
      question = next_question(keyword, person)
      answer_sheet = get_answer_sheet(keyword, person)
      if question
        question.set_response(answer, answer_sheet)
      end
    end
    
    def next_question(keyword, person)
      answer_sheet = get_answer_sheet(keyword, person)
      question = keyword.questions.detect {|q| q.response(answer_sheet).blank?}      
    end

end
