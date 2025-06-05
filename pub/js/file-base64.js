/// wikimusic - the free music knowledge encyclopaedia

// Copyright © Josep Bigorra <jjbigorra@gmail.com>

// wikimusic is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// wikimusic is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

const fileToBase64 = (file) => {
  return new Promise((resolve, reject) => {
    const fileReader = new FileReader()
    fileReader.readAsDataURL(file)

    fileReader.onload = () => {
      resolve(fileReader.result)
    }

    fileReader.onerror = (error) => {
      reject(error)
    }
  })
}

async function translateFileToBase64AddToInput(sourceInput, targetInput) {
  const file = sourceInput.files[0]
  const base64 = await fileToBase64(file)
  targetInput.setAttribute('value', base64)
};
