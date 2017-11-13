Rails.application.routes.draw do

  scope "#{Rails.application.config.app_url_prefix}" do
    get "/" => 'monitor#index'
    get "/sample" => 'sample#index'
    get "/availability_report" => 'sample#availability_report'
  end

end
