require 'mongoid'

module SesProxy
  class VerifiedSender
    include Mongoid::Document
    store_in collection: "verified_senders"

    field :ses_identity, type: String
    field :type, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime
  end
end