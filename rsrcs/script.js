function toggleDropdown(id) {
  const dropdown = document.getElementById(id);
  dropdown.classList.toggle("show");
}

function sendSelectedOptions(checkbox) {
  const dropdown = checkbox.closest('.dropdown-content');
  const dropdownId = dropdown.id;

  const checkboxes = dropdown.querySelectorAll("input[type='checkbox']:checked");
  const selectedValues = Array.from(checkboxes).map(checkbox => checkbox.value);

  const queryString = selectedValues.map(value => `selectedOptions=${encodeURIComponent(value)}`).join('&');

  fetch(`${SERVER_IP}/multi?qa=${DEVICE_ID}&id=${encodeURIComponent(dropdownId)}&${queryString}`)
    .then(response => response.json())
    .then(data => console.log('Success:', data))
    .catch(error => console.error('Error:', error));
}

window.onclick = function(event) {
  if (!event.target.matches('.dropbtn')) {
    const dropdowns = document.getElementsByClassName("dropdown-content");
    for (let i = 0; i < dropdowns.length; i++) {
      const openDropdown = dropdowns[i];
      if (openDropdown.classList.contains('show')) {
        openDropdown.classList.remove('show');
      }
    }
  }
}

function fetchAction(action, buttonId) {
  const url = `${SERVER_IP}/${action}?qa=${DEVICE_ID}&id=${encodeURIComponent(buttonId)}`;
  fetch(url)
    .then(() => console.log(`Action '${action}' triggered by button '${buttonId}'`))
    .catch(console.error);
}

function handleSliderInput(slider,indicator) {
  const value = slider.value;
  const sliderId = slider.id;

  // Update the value indicator
  const valueIndicator = document.getElementById(indicator);
  valueIndicator.textContent = value;

  // Construct the URL with the slider value and ID as query parameters
  const url = `${SERVER_IP}/slider?qa=${DEVICE_ID}&id=${encodeURIComponent(sliderId)}&value=${encodeURIComponent(value)}`;
  fetch(url)
    .then(() => console.log(`Slider value sent: ${value}, Slider ID: ${sliderId}`))
    .catch(console.error);
}

function handleDropdownChange(selectElement) {
  const selectedValue = selectElement.value;
  const dropdownId = selectElement.id;

  const url = `${SERVER_IP}/select?qa=${DEVICE_ID}&id=${encodeURIComponent(dropdownId)}&value=${encodeURIComponent(selectedValue)}`;
  fetch(url)
    .then(() => console.log(`Dropdown value sent: ${selectedValue}, Dropdown ID: ${dropdownId}`))
    .catch(console.error);
}

function toggleButtonState(button) {
  const isOn = button.dataset.state === "on";

  if (isOn) {
    button.dataset.state = "off";
    button.style.backgroundColor = "#4272a8";
    fetchActionWithState("switch", button.id, "off");
  } else {
    button.dataset.state = "on";
    button.style.backgroundColor = "blue";
    fetchActionWithState("switch", button.id, "on");
  }
}

function fetchActionWithState(action, buttonId, state) {
  const url = `${SERVER_IP}/${action}?qa=${DEVICE_ID}&id=${encodeURIComponent(buttonId)}&state=${encodeURIComponent(state)}`;
  fetch(url)
    .then(() => console.log(`Action '${action}' triggered by button '${buttonId}' with state '${state}'`))
    .catch(console.error);
}


function toggleDeviceStructure() {
  const structureDiv = document.getElementById("deviceStructure");
  const btn = document.getElementById("deviceStructureBtn");
  if (structureDiv.style.display === "none") {
    fetch(`${SERVER_IP}/getDeviceStructure?id=${DEVICE_ID}`)
    .then(response => response.json())
    .then(data => {
      document.getElementById("deviceStructureContent").textContent = JSON.stringify(data, null, 2);
      structureDiv.style.display = "block";
      btn.textContent = "Hide Device Structure";
    });
  } else {
    structureDiv.style.display = "none";
    btn.textContent = "Show Device Structure";
  }
}
