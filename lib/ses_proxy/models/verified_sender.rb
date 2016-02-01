require 'mongoid'

module SesProxy
  class VerifiedSender
    include Mongoid::Document
    store_in collection: "verified_senders"

    field :ses_identity, type: String
    field :type, type: String
    field :created_at, type: DateTime
    field :updated_at, type: DateTime

    def self.update_identities(client)
      print "Update verified identities... "
      resp = client.list_identities
      identities = resp.data[:identities]
      resp = client.get_identity_verification_attributes :identities => identities
      VerifiedSender.delete_all
      _resp = {:emails => [], :domains => []}.with_indifferent_access
      resp[:verification_attributes].each do |identity, attributes|
        _type = identity.match('@') ? 'email' : 'domain'
        next unless attributes[:verification_status].eql? "Success"
        _resp[_type.pluralize] << VerifiedSender.create({:ses_identity => identity, :type => _type, :created_at => Time.now, :updated_at => Time.now})
      end
      _resp
      puts "OK"
    end

  end
end