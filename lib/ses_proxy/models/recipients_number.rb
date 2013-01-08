require 'mongoid'

module SesProxy
  class RecipientsNumber
    include Mongoid::Document

    field :original, type: Integer
    field :filtered, type: Integer
    field :created_at, type: DateTime
    field :updated_at, type: DateTime
  end
end