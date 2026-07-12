defmodule MetersWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use MetersWeb, :html

  embed_templates "page_html/*"

  @doc """
  Renders translated validation errors for a single form field, styled to
  match the landing page. Renders nothing when the field has no errors.
  """
  attr :field, Phoenix.HTML.FormField, required: true

  def field_error(assigns) do
    ~H"""
    <p :for={msg <- Enum.map(@field.errors, &translate_error/1)} class="field-err">
      {msg}
    </p>
    """
  end

  @doc """
  Renders JSON-LD structured data (schema.org) for the landing page:
  a WebSite/Organization graph plus a FAQPage built from `faqs/0`, which
  makes the FAQ eligible for Google rich results.
  """
  def structured_data(assigns) do
    base = MetersWeb.Endpoint.url()

    graph = [
      %{
        "@type" => "WebSite",
        "@id" => base <> "/#website",
        "url" => base <> "/",
        "name" => "Martwe Metry",
        "inLanguage" => "pl-PL"
      },
      %{
        "@type" => "Organization",
        "@id" => base <> "/#organization",
        "name" => "Martwe Metry",
        "url" => base <> "/"
      },
      %{
        "@type" => "FAQPage",
        "@id" => base <> "/#faq",
        "mainEntity" =>
          Enum.map(faqs(), fn {question, answer} ->
            %{
              "@type" => "Question",
              "name" => question,
              "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
            }
          end)
      }
    ]

    json = Jason.encode!(%{"@context" => "https://schema.org", "@graph" => graph})
    assigns = assign(assigns, :json, json)

    ~H"""
    <script type="application/ld+json">
      <%= Phoenix.HTML.raw(@json) %>
    </script>
    """
  end

  @doc """
  FAQ questions and plain-text answers. Single source of truth shared by the
  rendered `<details>` list and the FAQPage structured data.
  """
  def faqs do
    [
      {"Skąd w ogóle ten problem?",
       "Norma PN-ISO 9836 stanowi, że powierzchnia pod trwałymi ścianami działowymi to powierzchnia konstrukcji, nie użytkowa. Część deweloperów mimo to wliczała ją do metrażu, od którego liczona była cena — czasem pod nazwą „powierzchnia rozliczeniowa”. Płaciłeś więc za metry, z których fizycznie nie korzystasz."},
      {"Czy każdemu należy się zwrot?",
       "Nie. Orzecznictwo nie jest jednolite: kluczowe jest, czy deweloper jasno poinformował Cię o sposobie liczenia powierzchni. Dlatego pierwszym krokiem jest zawsze bezpłatna analiza Twojej konkretnej umowy, a nie pozew."},
      {"Ile mam czasu?",
       "Roszczenia konsumenta przedawniają się co do zasady po 6 latach, z końcem roku kalendarzowego. Jeśli kupiłeś mieszkanie w 2020 r., czas może upłynąć z końcem tego roku — dlatego warto sprawdzić to teraz."},
      {"Ile to kosztuje?",
       "Analiza umowy jest bezpłatna. Jeśli sprawa rokuje i zdecydujesz się ją prowadzić, warunki finansowe przedstawi Ci kancelaria przed podpisaniem czegokolwiek — z reguły jest to model powiązany z wynikiem sprawy."}
    ]
  end
end
