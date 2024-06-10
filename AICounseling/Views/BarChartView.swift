import SwiftUI

struct BarChartView: View {
    let emotions: [Emotion]
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = emotions.map { $0.value }.max() ?? 1.0
            let barWidth = geometry.size.width / CGFloat(emotions.count)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(emotions) { emotion in
                    VStack {
                        Spacer()
                        Text(emotion.type.capitalized)
//                        Text(String(format: "%.5f", emotion.value))
                            .font(.caption)
                            .rotationEffect(.degrees(-90))
                            .offset(y: emotion.value == maxValue ? -20 : 0)
                        Rectangle()
                            .fill(emotion.color)
                            .frame(width: barWidth - 2, height: CGFloat(emotion.value / maxValue) * geometry.size.height)
                        Text(emotion.type.capitalized)
                            .font(.caption)
                            .fixedSize()
                            .frame(width: barWidth, height: 20)
                    }
                }
            }
        }
    }
}