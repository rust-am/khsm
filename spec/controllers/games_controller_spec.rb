require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  describe "Anon user" do
    context 'when Anon user trying to open game page(#show)' do
      # из экшена show анона посылаем
      it 'show alert and redirect to login page' do
        # вызываем экшен
        get :show, id: game_w_questions.id
        # проверяем ответ
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context 'when Anon user trying to create game (#create)' do
      it 'return nil game, show alert and redirect to login page' do
        post :create
        game = assigns(:game) # тянем игру

        expect(game).to eq nil # проверяем отсутствие
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when Anon user trying to give an answer (#answer)' do
      it 'return nil game, show alert and redirect to login page' do
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
        game = assigns(:game)

        expect(game).to eq nil
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when Anon user trying to take money in game (#take_money)' do
      it 'return nil game, show alert and redirect to login page' do
        put :take_money, id: game_w_questions.id
        game = assigns(:game)

        expect(game).to eq nil
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    describe "#show" do
      # юзер видит свою игру
      context "when user open the game(#show)" do
        it 'check user and render user page' do
          get :show, id: game_w_questions.id
          game = assigns(:game) # вытаскиваем из контроллера поле @game

          expect(game.finished?).to be_falsey
          expect(game.user).to eq(user)

          expect(response.status).to eq(200) # должен быть ответ HTTP 200
          expect(response).to render_template('show') # и отрендерить шаблон show
        end
      end

      context "when user trying to open other user game" do
        # проверка, что пользовтеля посылают из чужой игры
        it 'redirect to root and flash alert' do
          # создаем новую игру, юзер не прописан, будет создан фабрикой новый
          alien_game = FactoryGirl.create(:game_with_questions)

          # пробуем зайти на эту игру текущий залогиненным user
          get :show, id: alien_game.id

          expect(response.status).not_to eq(200) # статус не 200 ОК
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end

    describe "#create" do
      context "when user create game" do
        # юзер может создать новую игру
        it 'creates game' do
          # сперва накидаем вопросов, из чего собирать новую игру
          generate_questions(15)

          post :create
          game = assigns(:game) # вытаскиваем из контроллера поле @game

          # проверяем состояние этой игры
          expect(game.finished?).to be_falsey
          expect(game.user).to eq(user)
          # и редирект на страницу этой игры
          expect(response).to redirect_to(game_path(game))
          expect(flash[:notice]).to be
        end
      end

      context "when user trying to create new game while old one not finished" do
        # юзер пытается создать новую игру, не закончив старую
        it 'redirect to not finished game' do
          # убедились что есть игра в работе
          expect(game_w_questions.finished?).to be_falsey

          # отправляем запрос на создание, убеждаемся что новых Game не создалось
          expect { post :create }.to change(Game, :count).by(0)

          game = assigns(:game) # вытаскиваем из контроллера поле @game
          expect(game).to be_nil

          # и редирект на страницу старой игры
          expect(response).to redirect_to(game_path(game_w_questions))
          expect(flash[:alert]).to be
        end
      end
    end

    describe "#answer" do
      # юзер отвечает на игру корректно - игра продолжается
      context "when user answer correct" do
        it 'check game and redirect to the second question' do
          # передаем параметр params[:letter]
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
          game = assigns(:game)

          expect(game.finished?).to be_falsey
          expect(game.current_level).to be > 0
          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
        end
      end

      context "when user answer incorrect" do
        it 'check game/level and redirect to the user page' do
          # передаем параметр params[:letter]
          current_game_question = game_w_questions.current_game_question
          incorrect_answer = (current_game_question.variants.keys - [current_game_question.correct_answer_key]).sample
          put :answer, id: game_w_questions.id, letter: incorrect_answer
          game = assigns(:game)

          expect(game.finished?).to eq true
          expect(game.current_level).to eq 0
          expect(response).to redirect_to(user_path(user))
          expect(flash.empty?).to eq false
        end
      end
    end

    describe "#take_money" do
      # юзер берет деньги
      context " wnen user takes money" do
        it 'game ends, balance increases and user redirect to user page' do
          # вручную поднимем уровень вопроса до выигрыша 200
          game_w_questions.update_attribute(:current_level, 2)

          put :take_money, id: game_w_questions.id
          game = assigns(:game)
          expect(game.finished?).to be_truthy
          expect(game.prize).to eq(200)

          # пользователь изменился в базе, надо в коде перезагрузить!
          user.reload
          expect(user.balance).to eq(200)

          expect(response).to redirect_to(user_path(user))
          expect(flash[:warning]).to be
        end
      end
    end

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'check fifty_fifty availability' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to eq false

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)

      expect(game.finished?).to eq false
      expect(game.fifty_fifty_used).to eq true
      # проверяем наличие
      expect(game.current_game_question.help_hash[:fifty_fifty]).to be
      # что имеет варианта
      expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
      # имеет правильный вариант
      expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
      expect(response).to redirect_to(game_path(game))
    end
  end
end
