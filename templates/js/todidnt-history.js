// Constants

var margin = {
  top: 20,
  right: 20,
  bottom: 30,
  left: 50
};

var width = window.innerWidth * 0.70, height = 500;

// Graph scale setup

var x = d3.scale.ordinal()
  .rangeRoundBands([0, width], .1);

var y = d3.scale.linear()
  .rangeRound([height, 0]);

var color = d3.scale.category20b();

var getColor = function(name) {
  if (name === 'Other') {
    return "#ccc"; // gray
  } else {
    return color(name);
  }
};

var getGrayscaleColor = function(name) {
  var color = getColor(name);

  // Grayscale the color.
  hsl = d3.hsl(color);
  l = hsl.l;
  l = Math.min(l + ((1 - l) * 0.85), 0.95);

  return d3.hsl(hsl.h, 0, l);
}

var xAxis = d3.svg.axis()
  .scale(x)
  .orient("bottom");

var yAxis = d3.svg.axis()
  .scale(y)
  .orient("left")
  .tickFormat(d3.format(".2s"));

var tip = d3.tip()
  .attr('class', 'd3-tip')
  .offset([-10, 0])
  .html(function(d) { return d.name + " - " + (d.y1 - d.y0); });

// Transform data

var authors = PRELOADED_DATA['authors'];
color.domain(authors);

var data = PRELOADED_DATA['history'].map(function(d) {
  var y0 = 0
  var todos = color.domain().map(function(name) {
    return {
      name: name,
      y0: y0,
      y1: y0 += +(d[name] || 0)
    };
  });
  var total = todos[todos.length - 1].y1;

  return {date: d.Date, todos: todos, total: total};
});

// Graph creation

var svg = d3.select("#graph").append("svg")
  .attr("width", '100%')
  .attr("height", height + margin.top + margin.bottom)
  .append("g")
  .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

svg.call(tip);

x.domain(data.map(function(d) { return d.date; }));
y.domain([0, d3.max(data, function(d) { return d.total; })]);

var dates = svg.selectAll(".dates")
  .data(data)
  .enter().append("g")
  .attr("class", "g")
  .attr("transform", function(d) { return "translate(" + x(d.date) + ",0)"; });

dates.selectAll("rect")
  .data(function(d) { return d.todos; })
  .enter().append("rect")
  .attr("width", x.rangeBand())
  .attr("y", function(d) { return y(d.y1); })
  .attr("height", function(d) { return y(d.y0) - y(d.y1); })
  .style("fill", function(d) { return getColor(d.name); })
  .on("mouseover", tip.show)
  .on("mouseout", tip.hide);


// Axes

svg.append("g")
.attr("class", "x axis")
.attr("transform", "translate(0," + height + ")")
.call(xAxis);

svg.append("g")
  .attr("class", "y axis")
  .call(yAxis)
  .append("text")
  .attr("transform", "rotate(-90)")
  .attr("y", 6)
  .attr("dy", ".71em")
  .style("text-anchor", "end")
  .text("TODOs");

// Legend

var legend_svg = d3.select("#legend")
  .append('svg')
  .style("height", color.domain().length * 20)
  .style("width", "100%");

var legend = legend_svg.append('g')
  .attr("class", "legend");

legend.selectAll('rect')
  .data(color.domain().slice().reverse())
  .enter().append("rect")
  .attr("width", 18)
  .attr("height", 18)
  .attr("transform", function(d, i) { return "translate(0," + i * 20 + ")"; })
  .style("fill", getColor)
  .style("cursor", "pointer")
  .on('click', function(d, i) {
    j = color.domain().length - i - 1; // reversed for some reason
    dates.selectAll("rect").style("fill",
      function(d2, i2) {
        if (j != i2) {
          return getGrayscaleColor(d2.name);
        } else {
          return getColor(d2.name);
        }
      }
    )

    legend.selectAll("rect").style("fill",
      function(d2, i2) {
        if (i != i2) {
          return getGrayscaleColor(d2);
        } else {
          return getColor(d2);
        }
      }
    )
  })

legend.selectAll('text')
  .data(color.domain().slice().reverse())
  .enter().append("text")
  .attr("x", 25)
  .attr("y", 9)
  .attr("dy", ".35em")
  .attr("transform", function(d, i) { return "translate(0," + i * 20 + ")"; })
  .style("text-anchor", "beginning")
  .text(function(d) { return d; });
