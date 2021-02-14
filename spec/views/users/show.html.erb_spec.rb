require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:game) { FactoryGirl.build_stubbed(:game, created_at: Time.parse('2019.10.09, 13:00'), current_level: 6, prize: 1_000) }
  let(:user1) { FactoryGirl.create(:user, name: 'user1', balance: 32_000) }
  let(:user2) { FactoryGirl.create(:user, name: 'user2', balance: 2_000) }

  context 'when user is Anon' do
    before(:each) do
      assign(:user, user1)
      assign(:game, game)

      render
    end

    it 'show user name' do
      expect(rendered).to match 'user1'
    end

    it 'show profile editing button' do
      expect(rendered).not_to match 'Сменить имя и пароль'
    end

    it 'show game elements' do
      render partial: 'users/game', object: game

      expect(rendered).to match "#{game.id}"
      expect(rendered).to match '09 окт., 13:00'
    end
  end

  context 'when user in logged in' do
    before(:each) do
      sign_in user1
      assign(:user, user1)
      assign(:game, game)

      render
    end

    it 'show user name' do
      expect(rendered).to match('user1')
    end

    it 'profile editing button is not shown' do
      expect(rendered).to match('Сменить имя и пароль')
    end

    it 'show game elements' do
      render partial: 'users/game', object: game
      expect(rendered).to match "#{game.id}"
      expect(rendered).to match '09 окт., 13:00'
    end
  end
end
