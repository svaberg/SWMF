<?php    // If set, use passed value, otherwise use empty string
  $parameter = array('codename');
  foreach($parameter as $name) { $$name = isset($_GET[$name]) ? $_GET[$name] : ''; } ?>

<html>
<head>
<META HTTP-EQUIV=REFRESH CONTENT="0;URL=index.php">
</head>
<body>

<?php
   $return = "";
   Exec("cd ../codes;
         rm -rf CODE_$codename;
         rm -rf CODE[0-9]_$codename", $return);
//   foreach ($return as $tmp) {
//      echo "$tmp\n";
//   }
?>

</body>
