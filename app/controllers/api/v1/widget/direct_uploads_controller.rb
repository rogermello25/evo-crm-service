class Api::V1::Widget::DirectUploadsController < ActiveStorage::DirectUploadsController
  include WebsiteTokenHelper
  before_action :set_web_widget
  before_action :set_contact

  def create
    return if @contact.nil?

    super
  end
end
