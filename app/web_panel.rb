require 'sinatra'
require 'haml'
require 'kaminari/sinatra'
require 'json'
require 'aws-sdk'

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    available_users = SesProxy::Conf.get[:http_auth].map{|user| [user[:user],user[:password]]}
    @auth.provided? && @auth.basic? && @auth.credentials && available_users.include?(@auth.credentials)
  end
end

helpers Kaminari::Helpers::SinatraHelpers
module Kaminari::Helpers
  module SinatraHelpers
    class ActionViewTemplateProxy
      def render(*args)
        base = ActionView::Base.new.tap do |a|
          a.view_paths << File.expand_path('../views', __FILE__)
        end
        base.render(*args)
      end
    end
  end
end

configure :development do
  Sinatra::Application.reset!
end

get '/' do
  protected!
  @menu_item = "mails"
  @chart_url = "/mails.json"
  @page_title = "Sent Emails"
  @per = params[:per] || 20
  mails = mails_query
  @mails = mails.page(params[:page]).per(@per)
  haml :mails, :layout => "layout"
end

get '/mails.json' do
  protected!
  mails = mails_query
  d_array = (string_to_date(@s)..string_to_date(@e)).to_a
  recipients_number = SesProxy::RecipientsNumber.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
  data = {}
  grouped_collection = {}
  filtered_rate_collection = {}
  key_format = get_key_format d_array
  data[:x] = make_formatted_array d_array, key_format
  data[:y] ||= []
  data[:x].each do |d|
    grouped_collection[d] = mails.collect{|b| b if b.created_at.strftime(key_format).eql? d}.compact.size
    filtered_rate_collection[d] = recipients_number.collect{|b| b.filtered if b.created_at.strftime(key_format).eql? d}.compact.sum.to_f
  end
  data[:y] << {:name=>"Mails",:data=>grouped_collection.values}
  data[:y] << {:name=>"Sents",:data=>filtered_rate_collection.values}

  content_type :json
  data.to_json
end

get '/bounced_mails' do
  protected!
  @menu_item = "bounced_mails"
  @chart_url = "/bounced_mails.json"
  @page_title = "Bounced Emails"
  @per = params[:per] || 20
  mails = bounced_mails_query
  @mails = mails.page(params[:page]).per(@per)
  haml :mails, :layout => "layout"
end

get '/bounced_mails.json' do
  protected!
  mails = bounced_mails_query
  d_array = (string_to_date(@s)..string_to_date(@e)).to_a
  recipients_number = SesProxy::RecipientsNumber.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
  data = {}
  grouped_collection = {}
  bounced_rate_collection = {}
  key_format = get_key_format d_array
  data[:x] = make_formatted_array d_array, key_format
  data[:y] ||= []
  data[:x].each do |d|
    grouped_collection[d] = mails.collect{|b| b if b.created_at.strftime(key_format).eql? d}.compact.size
    original_size = recipients_number.collect{|b| b.original if b.created_at.strftime(key_format).eql? d}.compact.sum.to_f
    filtered_size = recipients_number.collect{|b| b.filtered if b.created_at.strftime(key_format).eql? d}.compact.sum.to_f
    bounced_rate_collection[d] = original_size - filtered_size
  end
  data[:y] << {:name=>"Mails",:data=>grouped_collection.values}
  data[:y] << {:name=>"Bounced Sents",:data=>bounced_rate_collection.values}

  content_type :json
  data.to_json
end

get '/bounces' do
  protected!
  @menu_item = "bounces"
  @chart_url = "/bounces.json"
  @per = params[:per] || 20
  bounces = bounces_query
  @bounces = bounces.page(params[:page]).per(@per)
  haml :bounces, :layout => "layout"
end

get '/bounces.json' do
  protected!
  bounces = bounces_query
  recipients_number = SesProxy::RecipientsNumber.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
  d_array = (string_to_date(@s)..string_to_date(@e)).to_a
  data = {}
  original_rate_collection = {}
  filtered_rate_collection = {}
  key_format = get_key_format d_array
  data[:x] = make_formatted_array d_array, key_format
  data[:y] ||= []
  data[:x].each do |d|
    bounces_size = bounces.collect{|b| b if b.created_at.strftime(key_format).eql? d}.compact.size.to_f
    original_size = recipients_number.collect{|b| b.original if b.created_at.strftime(key_format).eql? d}.compact.sum.to_f
    filtered_size = recipients_number.collect{|b| b.filtered if b.created_at.strftime(key_format).eql? d}.compact.sum.to_f
    if original_size > 0
      original_rate_collection[d] = (((bounces_size.to_f + original_size - filtered_size) / original_size) * 100).round(2)
    else
      original_rate_collection[d] = 0
    end
    if filtered_size > 0
      filtered_rate_collection[d] = ((bounces_size.to_f / filtered_size) * 100).round(2)
    else
      filtered_rate_collection[d] = 0
    end
  end
  data[:y] << {:name=>"Original Rate (%)",:data=>original_rate_collection.values}
  data[:y] << {:name=>"Filtered Rate (%)",:data=>filtered_rate_collection.values}

  content_type :json
  data.to_json
end

get "/refresh_senders" do
  protected!
  ses = ::AWS::SimpleEmailService.new(SesProxy::Conf.get[:aws])
  SesProxy::VerifiedSender.update_identities(ses.client)
  204
end

private

def get_key_format(d_array)
  if d_array.size <= 30
    #days
    key_format = "%d/%m/%Y"
  elsif d_array.size > 30 and d_array.size <= 210
    #weeks
    key_format = "%W/%Y"
  elsif d_array.size > 210
    #months
    key_format = "%B/%Y"
  end
  key_format
end

def make_formatted_array(d_array, key_format)
  return d_array.map{|d| d.to_date.strftime(key_format)}.uniq
end

def mails_query
  @q = params[:q]
  @s = params[:s]||(Date.today-1.month).strftime("%d-%m-%Y")
  @e = params[:e]||Date.today.strftime("%d-%m-%Y")
  if @q.nil? or @q.eql?""
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::Email.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
    else
      mails = SesProxy::Email
    end
  else
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::Email.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day}).any_of({:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i })
    else
      mails = SesProxy::Email.any_of({:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }).page(params[:page]).per(20)
    end
  end
end

def bounced_mails_query
  @q = params[:q]
  @s = params[:s]||(Date.today-1.month).strftime("%d-%m-%Y")
  @e = params[:e]||Date.today.strftime("%d-%m-%Y")
  if @q.nil? or @q.eql?""
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::BouncedEmail.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
    else
      mails = SesProxy::BouncedEmail
    end
  else
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::BouncedEmail.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day}).any_of({:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i })
    else
      mails = SesProxy::BouncedEmail.any_of({:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }).page(params[:page]).per(20)
    end
  end
end

def bounces_query
  @s = params[:s]||(Date.today-1.month).strftime("%d-%m-%Y")
  @e = params[:e]||Date.today.strftime("%d-%m-%Y")
  if valid_date(@s) and valid_date(@e)
    bounces = SesProxy::Bounce.where(:created_at=>{'$gte' => string_to_date(@s),'$lte' => string_to_date(@e)+1.day})
  else
    bounces = SesProxy::Bounce
  end
  bounces
end

def valid_date(d)
  begin
    d and not d.eql?"" and string_to_date(d)
  rescue Exception=>e
    false
  end
end

def string_to_date(d)
  Date.strptime(d, '%d-%m-%Y')
end
