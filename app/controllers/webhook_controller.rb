# frozen_string_literal: true

require "line/bot"

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  USE_GOOGLE_MAPS_API = true

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    end
  end

  def callback
    body = request.body.read

    signature = request.env["HTTP_X_LINE_SIGNATURE"]
    head 470 unless client.validate_signature(body, signature)

    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          begin

          api = USE_GOOGLE_MAPS_API ? GoogleMapsApiService.new : GeoApiService.new

          input_list = api.format_input_message(event.message["text"])
          api.validate(input_list)
          location_list = input_list.map do |input|
            api.generate_location_list(input)
          end
          required_time_list, total_required_time = optimized_location_to_required_time(location_list, api)
          message = generate_message(required_time_list, total_required_time)
          Rails.logger.info("Message: #{event.message["text"]}")

        rescue Services::ValidationException, Services::NotFoundException, Services::ApiUnknownException => e
          message = e.message_for_user
          Rails.logger.error("Exception: #{message}\nMessage: #{event.message["text"]}")
        rescue => e
          message = "何かしらのエラーが発生しました。時間をあけてから再びアクセスしてね。"
          Rails.logger.error("#{e.message}\nMessage: #{event.message["text"]}")
        end
          client.reply_message(event["replyToken"], { type: "text", text: message })
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message["id"])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    end
    head :ok
  end

  private
    def optimized_location_to_required_time(location_list, api)
      initial_location = location_list[0]
      location_list_set = location_list[1..-1].permutation(location_list.length - 1).to_a

      # 愚直に全探索 変更予定（優先度低）
      optimized_required_time_list = nil
      optimized_total_required_time = nil

      location_list_set.each do |location_set|
        required_time_list = []
        required_time_list << api.location_to_time(initial_location, location_set[0]) # 出発地点-->最初の目的地
        location_set.each_cons(2) { |location_from, location_to|
          required_time_list << api.location_to_time(location_from, location_to)
        }
        required_time_list << api.location_to_time(location_set[location_set.length - 1], initial_location) # 最後の目的地-->出発地点（最終地点）

        total_required_time = required_time_list.sum { |hash| hash[:time] }

        if optimized_total_required_time.blank? || (total_required_time < optimized_total_required_time)
          optimized_required_time_list = required_time_list
          optimized_total_required_time = total_required_time
        end
      end
      return optimized_required_time_list, optimized_total_required_time
    end

    def time_formatter(second)
      hours = (second / 3600).floor(0)
      minutes = ((second - hours * 3600) / 60).floor(0)
      "#{hours}時間#{minutes}分"
    end

    def generate_message(required_time_list, total_required_time)
      message = "こんにちは。\nお問い合わせありがとうございます。\n\n最適な経路は、\n"

      required_time_list.each do |required_time|
        if USE_GOOGLE_MAPS_API
          message += "#{required_time[:location_from]}から#{required_time[:location_to]}までの所要時間は#{time_formatter(required_time[:time])}\n"
        else
          message += "〒#{required_time[:location_from].clone.insert(3, '-')}から〒#{required_time[:location_to].clone.insert(3, '-')}までの所要時間は#{time_formatter(required_time[:time])}\n"
        end
      end
      message += "だよ。\n全移動時間は#{time_formatter(total_required_time)}だよ。"
      message
    end
end
