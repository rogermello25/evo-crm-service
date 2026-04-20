class ApiController < ApplicationController
  def index
    render json: { version: Evolution.config[:version],
                   timestamp: Time.now.utc.to_fs(:db),
                   queue_services: redis_status,
                   data_services: postgres_status }
  end

  private

  def redis_status
    r = Redis.new(Redis::Config.app)
    'ok' if r.ping
  rescue Redis::CannotConnectError
    'failing'
  end

  def postgres_status
    ActiveRecord::Base.connection.active? ? 'ok' : 'failing'
  rescue ActiveRecord::ConnectionNotEstablished
    'failing'
  end
end
