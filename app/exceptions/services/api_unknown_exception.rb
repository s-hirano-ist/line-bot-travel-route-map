# frozen_string_literal: true

class Services::ApiUnknownException < StandardError
  attr_reader :message_for_user
  def initialize
    @message_for_user = "何かしらのエラーが発生しました。時間をあけてから再びアクセスしてね。"
    super()
  end
end
