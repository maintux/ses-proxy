require 'mongoid'

module SesProxy
  class Email
    include Mongoid::Document

    field :sender, type: String
    field :recipients, type: String
    field :subject, type: String
    field :body, type: String
    field :system, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime
  end
end