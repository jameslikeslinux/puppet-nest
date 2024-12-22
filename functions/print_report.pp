# Print apply results like a Puppet report
# @param apply_results Result set from apply block
# @return none
# @api private
function nest::print_report(ResultSet $apply_results) {
  $apply_results.each |$result| {
    if $result.report {
      $result.report['logs'].each |$log| {
        out::message("${log['level'].capitalize}: ${log['source']}: ${log['message']}")
      }
    }
  }
}
