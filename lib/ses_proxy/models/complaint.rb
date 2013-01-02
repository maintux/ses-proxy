require 'mongoid'

module SesProxy
  class Complaint
    include Mongoid::Document
    store_in collection: "complained"

    field :email, type: String
    field :type, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime
  end
end