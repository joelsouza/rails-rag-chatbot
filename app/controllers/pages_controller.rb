class PagesController < ApplicationController
  def index
    @result = ActiveRecord::Base.connection.execute("SELECT 1")
  end
end
