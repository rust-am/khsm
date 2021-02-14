require 'rails_helper'

RSpec.feature 'USER visits other user profile', type: :feature do

  let(:user1) { FactoryGirl.create :user, name: "первый" }
  let(:user2) { FactoryGirl.create :user, name: "второй", balance: 4_000 }

  let!(:games) do
    [
      FactoryGirl.create(:game, user: user2, created_at: Time.parse('2021.01.05, 13:00'), finished_at: Time.parse('2021.01.05, 13:30'),  current_level: 7, prize: 4_000),
      FactoryGirl.create(:game, user: user2, created_at: Time.parse('2021.02.11, 14:00'), current_level: 14)
    ]
  end

  before(:each) do
    login_as user1
  end

  scenario 'success' do
    visit "/"
    expect(page).to have_content "первый - 0 ₽"
    expect(page).to have_content "второй"

    click_link "второй"
    expect(page).to have_current_path "/users/#{user2.id}"

    expect(page).to have_content 'второй'
    expect(page).not_to have_content 'Сменить имя и пароль'

    expect(page).to have_content "#{games[0].id}"
    expect(page).to have_content '05 янв., 13:00'
    expect(page).to have_content 'деньги'
    expect(page).to have_content '7'
    expect(page).to have_content '4 000 ₽'

    expect(page).to have_content "#{games[1].id}"
    expect(page).to have_content '11 февр., 14:00'
    expect(page).to have_content 'в процессе'
    expect(page).to have_content '14'
    expect(page).to have_content '0 ₽'
  end
end
