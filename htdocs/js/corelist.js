function toggle (type) {
    var tr = document.getElementsByTagName("tr");
    for (i=0; i < tr.length; i++) {
        if (tr[i].id.indexOf(type) == 0) {
            if (toggleState[type] == 1) {
                tr[i].className += " invisible";  
            }
            else {
                tr[i].className = type;
            }
        }
    }
    if (toggleState[type] == 1) {
        toggleState[type] = 0;
    }
    else {
        toggleState[type] = 1;
    }
}

