# A SurveyResponse is a complete collection of answers given in response to the survey Questions.
class SurveyResponse < ApplicationRecord

  require 'csv'
  require 'openai'

  after_save_commit :enqueue_export_to_graph
  after_create :enqueue_keyword_extraction
  after_create :enqueue_sentiment_analysis

  validates_presence_of :response_id
  validates_uniqueness_of :response_id

  # Displays the query and its explanation for locating the SurveyResponse's associated Persona in the graph.
  def graph_query
    {
      explainer: "Access and explore this participant's response data (and all of its relationships) as an Interactive Persona in the TMI-Graph app.",
      query: "MATCH (p:Persona)-[]-(n) WHERE p.permalink=\"#{permalink}\" RETURN p,n"
    }
  end

  # Convenience method to pad ID.
  def identifier
    self.id.to_s.rjust(4, "0")
  end

   # Calculates the permanent URL of the SurveyResponse, which is stored as a property on the associated Persona.
  def permalink
    if Rails.env == "development"
      Rails.application.routes.url_helpers.url_for(controller: "survey_responses", action: "show", host: "localhost", port: 3000, id: self.id)
    else
      Rails.application.routes.url_helpers.url_for(controller: "survey_responses", action: "show", host: ENV.fetch("HOSTNAME", "localhost"), id: self.id)
    end
  end

  # Calculates and sets the sentiment based on a the "identity reflection / notes" field.
  # This method uses the SentimentAnalysis service, passing the text of the reflection as an
  # argument. The service returns a classification, which is written to the SurveyResponse record.
  def classify_sentiment
    if response = SentimentAnalysis.perform(self.notes)
      update_attribute :sentiment, response
      return response
    end
    return false
  end

  private

    # Creates a KeywordExtractorJob and pushes it into the background job queue.
    def enqueue_keyword_extraction
      KeywordExtractorJob.perform_async(self.id)
    end

    # Creates a SentimentAnalysisJob and pushes it into the background job queue.
    def enqueue_sentiment_analysis
      SentimentAnalysisJob.perform_async(self.id)
    end

    # Invokes a service to update the graph databases from this SurveyResponse object.
    def enqueue_export_to_graph
      ExportToGraphJob.perform_async(self.id)
    end

end
