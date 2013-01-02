require 'mongoid'

module SesProxy
  class Bounce
    include Mongoid::Document
    store_in collection: "bounced"

    field :email, type: String
    field :type, type: String
    field :desc, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime
  end
end