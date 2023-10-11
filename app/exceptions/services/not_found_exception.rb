# frozen_string_literal: true

class Services::NotFoundException < StandardError
  attr_reader :message_for_user
  def initialize(type)
    case type
    when "zipcode"
      @message_for_user = "入力された郵便番号は登録されてないよ。"
    when "keyword"
      @message_for_user = "入力された場所は登録されてないよ。"
    end
    super()
  end
end
