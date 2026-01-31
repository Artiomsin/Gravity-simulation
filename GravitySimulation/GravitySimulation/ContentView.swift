import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Гравитационная симуляция")
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            Text("Здесь будет визуализация тел")
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}
#Preview {
    ContentView()
}


