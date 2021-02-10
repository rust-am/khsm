require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe Game, type: :model do
  let(:user) { FactoryGirl.create(:user) }

  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      generate_questions(60)

      game = nil

      expect { game = Game.create_game_for_user!(user) }.to change(Game, :count).by(1).and(
        change(GameQuestion, :count).by(15).and(
          change(Question, :count).by(0)
        )
      )

      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  context 'game mechanics' do
    it 'answer correct continues game' do
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      expect(game_w_questions.current_level).to eq(level + 1)

      expect(game_w_questions.current_game_question).not_to eq(q)

      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  context '.take_money!' do
    it 'return correct data when game finished' do
      game_w_questions.answer_current_question!(game_w_questions.current_game_question.correct_answer_key)

      game_w_questions.take_money!

      expect(game_w_questions.prize).to be > 0

      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq game_w_questions.prize
    end
  end

  context '.status' do
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  describe "#current_game_question" do
    it "return current game question" do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[0])
    end
  end

  describe "#previous_level" do
    it "return previous level" do
      expect(game_w_questions.previous_level).to eq(-1)
    end
  end

  describe "#answer_current_question!" do
    it "should return true if correct answer" do
      level = game_w_questions.current_level
      correct_answer_key = game_w_questions.game_questions[level].correct_answer_key

      expect(game_w_questions.answer_current_question!(correct_answer_key)).to eq true
    end

    it "should return false if not correct answer" do
      expect(game_w_questions.answer_current_question!('something')).to eq false
    end

    it "should return false if time is out" do
      game_w_questions.created_at = Game::TIME_LIMIT.ago
      level = game_w_questions.current_level
      correct_answer_key = game_w_questions.game_questions[level].correct_answer_key

      expect(game_w_questions.answer_current_question!(correct_answer_key)).to eq false
    end

    it "should return true if last question is true" do
      game_w_questions.current_level = 14 # отсчет от 0, как индекс
      level = game_w_questions.current_level
      correct_answer_key = game_w_questions.game_questions[level].correct_answer_key

      expect(game_w_questions.answer_current_question!(correct_answer_key)).to eq true
    end
  end
end
