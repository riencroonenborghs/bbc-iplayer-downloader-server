class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :trackable, :validatable
  include DeviseTokenAuth::Concerns::User

  has_many :downloads, dependent: :destroy

  def to_json
    {id: id, email: email}
  end
end
