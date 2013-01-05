window.Chart = {
  make_chart_from_ajax_call: function(form, chartdiv) {
    return $.get(form.attr("data-ajax-url"), form.serialize(), function(data, state, xhr) {
      if (!data) {
        data = {
          x: [],
          y: []
        };
      }
      if (Chart.options.xAxis) {
        Chart.options.xAxis.categories = data.x;
        Chart.options.xAxis.labels.step = Chart.get_step(data.x, chartdiv);
      }
      Chart.options.series = data.y;
      if (Chart.options.plotOptions.series) {
        Chart.options.plotOptions.series.marker.enabled = Chart.show_marker(data.x, chartdiv);
      }
      return new Highcharts.Chart(Chart.options);
    });
  },
  show_marker: function(categories, chartdiv) {
    var width;
    width = $("#" + chartdiv).width() - 150;
    return !(width / categories.length <= 35);
  },
  get_step: function(categories, chartdiv) {
    var i, max_label_width, max_labels, ret, width;
    width = $("#" + chartdiv).width() - 150;
    max_label_width = 120;
    max_labels = Math.floor(width / max_label_width);
    return Math.floor((categories.length / max_labels) * 2);
  }
};

$(function(){
  var chart;
  Chart.options = {
    chart: {
      renderTo: 'chartdiv',
      type: 'spline'
    },
    title: {
      text: "" + ($('.page-title').html())
    },
    xAxis: {
      categories: [],
      labels: {
        step: 1
      }
    },
    yAxis: {
      title: {
        text: ""
      }
    },
    tooltip: {
      crosshairs: true,
      shared: true
    },
    plotOptions: {
      spline: {
        marker: {
          radius: 4,
          lineColor: '#666666',
          lineWidth: 1
        }
      },
      series: {
        marker: {
          enabled: true
        },
      }
    },
    series: []
  };

  chart = Chart.make_chart_from_ajax_call($("form[data-chart=chartdiv]"), "chartdiv");

  $(".date").datepicker()
})

