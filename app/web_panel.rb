require 'sinatra'
require 'haml'
require 'kaminari/sinatra'

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
  if params[:q].nil? or params[:q].eql?""
    @mails = SesProxy::Email.page(params[:page]).per(20)
  else
    @mails = SesProxy::Email.any_of({ :recipients => /.*#{params[:q]}.*/i }).page(params[:page]).per(20)
  end
  haml :mails
end

get '/bounces' do
  protected!
  @menu_item = "bounces"
  if params[:q].nil? or params[:q].eql?""
    @bounces = SesProxy::Bounce.page(params[:page]).per(20)
  else
    @bounces = SesProxy::Bounce.any_of({ :email => /.*#{params[:q]}.*/i }).page(params[:page]).per(20)
  end
  haml :bounces
end