require 'sinatra'
require 'haml'
require 'kaminari/sinatra'
require 'json'

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [SesProxy::Conf.get[:smtp_auth][:user], SesProxy::Conf.get[:smtp_auth][:password]]
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
  @per = params[:per] || 20
  mails = mails_query
  @mails = mails.page(params[:page]).per(@per)
  haml :mails
end

get '/mails.json' do
  protected!
  mails = mails_query
  d_array = (string_to_date(@s)..string_to_date(@e)).to_a
  data = get_data_json "Mails", mails, "created_at", d_array
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
  haml :bounces
end

get '/bounces.json' do
  protected!
  bounces = bounces_query
  d_array = (string_to_date(@s)..string_to_date(@e)).to_a
  data = get_data_json "Bounced", bounces, "created_at", d_array
  content_type :json
  data.to_json
end

private

def get_data_json(name, collection, method, d_array)
  data = {}
  grouped_collection = {}
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
  data[:x] = d_array.map{|d| d.to_date.strftime(key_format)}.uniq
  data[:y] ||= []
  data[:x].each do |d|
    grouped_collection[d] = collection.collect{|b| b if b.send(method).strftime(key_format).eql? d}.compact.size
  end
  data[:y] << {:name=>name,:data=>grouped_collection.values}
  data
end

def mails_query
  @q = params[:q]
  @s = params[:s]||(Date.today-1.month).strftime("%d-%m-%Y")
  @e = params[:e]||Date.today.strftime("%d-%m-%Y")
  if @q.nil? or @q.eql?""
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::Email.any_of(:created_at=>{'$gte' => string_to_date(@s),'$lt' => string_to_date(@e)})
    elsif valid_date(@s)
      mails = SesProxy::Email.any_of(:created_at=>{"$gte"=>string_to_date(@s)})
    elsif valid_date(@e)
      mails = SesProxy::Email.any_of(:created_at=>{"$lte"=>string_to_date(@e)})
    else
      mails = SesProxy::Email.all
    end
  else
    if valid_date(@s) and valid_date(@e)
      mails = SesProxy::Email.any_of(:created_at=>{'$gte' => string_to_date(@s),'$lt' => string_to_date(@e)}, "$or" => [{:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }])
    elsif valid_date(@s)
      mails = SesProxy::Email.any_of(:created_at=>{"$gte"=>string_to_date(@s)}, "$or" => [{:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }])
    elsif valid_date(@e)
      mails = SesProxy::Email.any_of(:created_at=>{"$lte"=>string_to_date(@e)}, "$or" => [{:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }])
    else
      mails = SesProxy::Email.any_of("$or" => [{:recipients => /.*#{@q}.*/i },{:sender => /.*#{@q}.*/i },{:system => /.*#{@q}.*/i },{:subject => /.*#{@q}.*/i }]).page(params[:page]).per(20)
    end
  end
end

def bounces_query
  @q = params[:q]
  @s = params[:s]||(Date.today-1.month).strftime("%d-%m-%Y")
  @e = params[:e]||Date.today.strftime("%d-%m-%Y")
  if @q.nil? or @q.eql?""
    if valid_date(@s) and valid_date(@e)
      bounces = SesProxy::Bounce.any_of(:created_at=>{'$gte' => string_to_date(@s),'$lt' => string_to_date(@e)})
    elsif valid_date(@s)
      bounces = SesProxy::Bounce.any_of(:created_at=>{"$gte"=>string_to_date(@s)})
    elsif valid_date(@e)
      bounces = SesProxy::Bounce.any_of(:created_at=>{"$lte"=>string_to_date(@e)})
    else
      bounces = SesProxy::Bounce.all
    end
  else
    if valid_date(@s) and valid_date(@e)
      bounces = SesProxy::Bounce.any_of(:created_at=>{'$gte' => string_to_date(@s),'$lt' => string_to_date(@e)}, "$or" => [{:email => /.*#{@q}.*/i },{ :type => /.*#{@q}.*/i },{ :desc => /.*#{@q}.*/i }])
    elsif valid_date(@s)
      bounces = SesProxy::Bounce.any_of(:created_at=>{"$gte"=>string_to_date(@s)}, "$or" => [{:email => /.*#{@q}.*/i },{ :type => /.*#{@q}.*/i },{ :desc => /.*#{@q}.*/i }])
    elsif valid_date(@e)
      bounces = SesProxy::Bounce.any_of(:created_at=>{"$lte"=>string_to_date(@e)}, "$or" => [{:email => /.*#{@q}.*/i },{ :type => /.*#{@q}.*/i },{ :desc => /.*#{@q}.*/i }])
    else
      bounces = SesProxy::Bounce.any_of("$or" => [{:email => /.*#{@q}.*/i },{ :type => /.*#{@q}.*/i },{ :desc => /.*#{@q}.*/i }])
    end
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
